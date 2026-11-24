// geotiff_test.cpp — unit tests for geotiff.hpp. No GDAL, no Python: an in-test TIFF
// writer builds the files in memory (layout x planar config x data type x byte order x
// BigTIFF x sparse), plus georeferencing, nodata, overviews, unsupported subsets and
// truncated / corrupted input. Exit code 0 = all checks passed.
#include "geotiff/geotiff.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

using geotiff::DataType;
using geotiff::Reader;
using geotiff::Status;

// --- tiny check harness -----------------------------------------------------------------

static long g_checks = 0, g_failed = 0;
static std::string g_context;

#define CHECK(cond)                                                                          \
    do {                                                                                     \
        ++g_checks;                                                                          \
        if (!(cond)) {                                                                       \
            if (++g_failed <= 40)                                                            \
                std::printf("FAIL %s:%d: %s   [%s]\n", __FILE__, __LINE__, #cond,            \
                            g_context.c_str());                                              \
        }                                                                                    \
    } while (0)

// --- in-test TIFF writer ----------------------------------------------------------------

static bool hostLittle() {
    const std::uint16_t one = 1;
    unsigned char b;
    std::memcpy(&b, &one, 1);
    return b == 1;
}

struct Field {
    std::uint16_t tag = 0;
    std::uint16_t type = 0;  // 2 ASCII, 3 SHORT, 4 LONG, 12 DOUBLE, 16 LONG8
    std::vector<std::uint64_t> ints;
    std::vector<double> doubles;
    std::string text;
};
static Field ints(std::uint16_t tag, std::uint16_t type, std::vector<std::uint64_t> v) {
    Field f;
    f.tag = tag;
    f.type = type;
    f.ints = std::move(v);
    return f;
}
static Field doubles(std::uint16_t tag, std::vector<double> v) {
    Field f;
    f.tag = tag;
    f.type = 12;
    f.doubles = std::move(v);
    return f;
}
static Field ascii(std::uint16_t tag, const std::string& text) {
    Field f;
    f.tag = tag;
    f.type = 2;
    f.text = text;
    return f;
}

struct ImageSpec {
    std::uint32_t w = 40, h = 37;
    bool tiled = true;
    std::uint32_t bw = 16, bh = 16;  // tile size, or bh = rows per strip
    unsigned bands = 1;
    bool separate = false;
    DataType dt = DataType::UInt8;
    bool sparse = false;
    bool allAbsent = false;
    std::uint32_t subfile = 0;
    int level = 0;
    std::uint16_t compression = 1;
    std::uint16_t predictor = 1;
    std::int64_t offsetBias = 0;       // added to every stored block offset
    std::uint64_t countCut = 0;        // subtracted from every stored byte count
    std::vector<Field> extra;          // added; replaces a default field of the same tag
    std::vector<std::uint16_t> omit;   // default fields to leave out
};
struct FileSpec {
    bool le = true;
    bool big = false;
    std::vector<ImageSpec> images;
    bool loop = false;  // last IFD points back to the first
};

static long long sampleValue(int level, unsigned band, std::uint64_t x, std::uint64_t y) {
    return 1 + static_cast<long long>(x) * 7 + static_cast<long long>(y) * 13 + band * 31 + level * 5;
}
// The typed sample for value v, as `size` bytes in the given byte order.
static void encodeSample(DataType dt, long long v, bool le, unsigned char* out) {
    unsigned size = geotiff::dataTypeSize(dt);
    switch (dt) {
        case DataType::UInt8: { auto x = static_cast<std::uint8_t>(v); std::memcpy(out, &x, 1); break; }
        case DataType::Int8: { auto x = static_cast<std::int8_t>(static_cast<std::uint8_t>(v + 100)); std::memcpy(out, &x, 1); break; }
        case DataType::UInt16: { auto x = static_cast<std::uint16_t>(v * 3); std::memcpy(out, &x, 2); break; }
        case DataType::Int16: { auto x = static_cast<std::int16_t>(v * 3 - 1000); std::memcpy(out, &x, 2); break; }
        case DataType::UInt32: { auto x = static_cast<std::uint32_t>(v * 70001); std::memcpy(out, &x, 4); break; }
        case DataType::Int32: { auto x = static_cast<std::int32_t>(v * 70001 - 50000000); std::memcpy(out, &x, 4); break; }
        case DataType::UInt64: { auto x = static_cast<std::uint64_t>(v) * 0x100000001ull; std::memcpy(out, &x, 8); break; }
        case DataType::Int64: { auto x = -static_cast<std::int64_t>(v) * 0x100000001ll; std::memcpy(out, &x, 8); break; }
        case DataType::Float32: { auto x = static_cast<float>(v) * 0.25f - 100.0f; std::memcpy(out, &x, 4); break; }
        case DataType::Float64: { auto x = static_cast<double>(v) * 0.125 - 1000.0; std::memcpy(out, &x, 8); break; }
        case DataType::Unknown: break;
    }
    if (le != hostLittle()) std::reverse(out, out + size);
}
static bool absent(const ImageSpec& im, std::uint32_t bx, std::uint32_t by, unsigned plane) {
    return im.allAbsent || (im.sparse && (bx + 2 * by + plane) % 3 == 0);
}

struct Out {
    std::vector<std::uint8_t> b;
    bool le = true;
    void put(std::uint64_t v, unsigned size) {
        for (unsigned i = 0; i < size; ++i)
            b.push_back(static_cast<std::uint8_t>(v >> (8 * (le ? i : size - 1 - i))));
    }
    void patch(std::size_t at, std::uint64_t v, unsigned size) {
        for (unsigned i = 0; i < size; ++i)
            b[at + i] = static_cast<std::uint8_t>(v >> (8 * (le ? i : size - 1 - i)));
    }
    void even() {
        if (b.size() % 2) b.push_back(0);
    }
};

static unsigned fieldTypeSize(std::uint16_t type) {
    return type == 3 ? 2 : type == 4 ? 4 : (type == 12 || type == 16) ? 8 : 1;
}
static std::vector<std::uint8_t> fieldBytes(const Field& f, bool le) {
    Out o;
    o.le = le;
    if (f.type == 2) {
        for (char c : f.text) o.b.push_back(static_cast<std::uint8_t>(c));
        o.b.push_back(0);
    } else if (f.type == 12) {
        for (double d : f.doubles) {
            std::uint64_t bits;
            std::memcpy(&bits, &d, 8);
            o.put(bits, 8);
        }
    } else {
        for (std::uint64_t v : f.ints) o.put(v, fieldTypeSize(f.type));
    }
    return o.b;
}

static std::vector<std::uint8_t> build(const FileSpec& spec) {
    Out o;
    o.le = spec.le;
    const unsigned offBytes = spec.big ? 8 : 4;
    o.b.push_back(spec.le ? 'I' : 'M');
    o.b.push_back(spec.le ? 'I' : 'M');
    o.put(spec.big ? 43 : 42, 2);
    if (spec.big) {
        o.put(8, 2);
        o.put(0, 2);
    }
    std::size_t linkAt = o.b.size();  // where the offset of the next IFD goes
    o.put(0, offBytes);
    std::uint64_t firstIfd = 0;

    for (const ImageSpec& im : spec.images) {
        const unsigned size = geotiff::dataTypeSize(im.dt);
        const std::uint32_t bw = im.tiled ? im.bw : im.w;
        const std::uint32_t bh = im.tiled ? im.bh : std::min(im.bh, im.h);
        const std::uint32_t nx = (im.w + bw - 1) / bw, ny = (im.h + bh - 1) / bh;
        const unsigned planes = im.separate ? im.bands : 1, spp = im.separate ? 1 : im.bands;
        std::vector<std::uint64_t> offsets, counts;
        for (unsigned plane = 0; plane < planes; ++plane)
            for (std::uint32_t by = 0; by < ny; ++by)
                for (std::uint32_t bx = 0; bx < nx; ++bx) {
                    if (absent(im, bx, by, plane)) {
                        offsets.push_back(0);
                        counts.push_back(0);
                        continue;
                    }
                    o.even();
                    const std::size_t start = o.b.size();
                    const std::uint32_t rows = im.tiled ? bh : std::min(bh, im.h - by * bh);
                    for (std::uint32_t y = 0; y < rows; ++y)
                        for (std::uint32_t x = 0; x < bw; ++x)
                            for (unsigned s = 0; s < spp; ++s) {
                                unsigned char sample[8];
                                encodeSample(im.dt, sampleValue(im.level, im.separate ? plane : s,
                                                                std::uint64_t(bx) * bw + x,
                                                                std::uint64_t(by) * bh + y),
                                             spec.le, sample);
                                o.b.insert(o.b.end(), sample, sample + size);
                            }
                    offsets.push_back(static_cast<std::uint64_t>(static_cast<std::int64_t>(start) + im.offsetBias));
                    counts.push_back(o.b.size() - start - im.countCut);
                }

        const std::uint16_t bits = static_cast<std::uint16_t>(size * 8);
        const bool isFloat = im.dt == DataType::Float32 || im.dt == DataType::Float64;
        const bool isSigned = im.dt == DataType::Int8 || im.dt == DataType::Int16 ||
                              im.dt == DataType::Int32 || im.dt == DataType::Int64;
        const std::uint16_t offType = spec.big ? 16 : 4;
        std::vector<Field> fields;
        if (im.subfile) fields.push_back(ints(254, 4, {im.subfile}));
        fields.push_back(ints(256, 4, {im.w}));
        fields.push_back(ints(257, 4, {im.h}));
        fields.push_back(ints(258, 3, std::vector<std::uint64_t>(im.bands, bits)));
        fields.push_back(ints(259, 3, {im.compression}));
        fields.push_back(ints(262, 3, {1}));
        fields.push_back(ints(277, 3, {im.bands}));
        fields.push_back(ints(284, 3, {im.separate ? 2u : 1u}));
        if (im.predictor != 1) fields.push_back(ints(317, 3, {im.predictor}));
        fields.push_back(ints(339, 3, std::vector<std::uint64_t>(im.bands, isFloat ? 3u : isSigned ? 2u : 1u)));
        if (im.tiled) {
            fields.push_back(ints(322, 4, {bw}));
            fields.push_back(ints(323, 4, {bh}));
            fields.push_back(ints(324, offType, offsets));
            fields.push_back(ints(325, offType, counts));
        } else {
            fields.push_back(ints(273, offType, offsets));
            fields.push_back(ints(278, 4, {im.bh}));
            fields.push_back(ints(279, offType, counts));
        }
        for (const Field& e : im.extra) {
            auto it = std::find_if(fields.begin(), fields.end(), [&](const Field& f) { return f.tag == e.tag; });
            if (it != fields.end()) *it = e;
            else fields.push_back(e);
        }
        for (std::uint16_t tag : im.omit)
            fields.erase(std::remove_if(fields.begin(), fields.end(), [&](const Field& f) { return f.tag == tag; }),
                         fields.end());
        std::sort(fields.begin(), fields.end(), [](const Field& a, const Field& b) { return a.tag < b.tag; });

        o.even();
        const std::uint64_t ifdAt = o.b.size();
        if (firstIfd == 0) firstIfd = ifdAt;
        o.patch(linkAt, ifdAt, offBytes);
        const unsigned entryBytes = spec.big ? 20 : 12;
        std::uint64_t external = ifdAt + (spec.big ? 8 : 2) + fields.size() * entryBytes + offBytes;
        std::vector<std::uint8_t> tail;
        o.put(fields.size(), spec.big ? 8 : 2);
        for (const Field& f : fields) {
            std::vector<std::uint8_t> data = fieldBytes(f, spec.le);
            o.put(f.tag, 2);
            o.put(f.type, 2);
            o.put(data.size() / fieldTypeSize(f.type), offBytes);
            if (data.size() <= offBytes) {
                data.resize(offBytes, 0);
                o.b.insert(o.b.end(), data.begin(), data.end());
            } else {
                o.put(external + tail.size(), offBytes);
                tail.insert(tail.end(), data.begin(), data.end());
                if (tail.size() % 2) tail.push_back(0);
            }
        }
        linkAt = o.b.size();
        o.put(0, offBytes);
        o.b.insert(o.b.end(), tail.begin(), tail.end());
    }
    if (spec.loop) o.patch(linkAt, firstIfd, offBytes);
    return o.b;
}

// --- expected block contents ------------------------------------------------------------

static std::vector<std::uint8_t> expectedBlock(const ImageSpec& im, std::uint32_t bx, std::uint32_t by,
                                               unsigned band) {
    const unsigned size = geotiff::dataTypeSize(im.dt);
    const std::uint32_t bw = im.tiled ? im.bw : im.w;
    const std::uint32_t bh = im.tiled ? im.bh : std::min(im.bh, im.h);
    std::vector<std::uint8_t> e(std::size_t(bw) * bh * size, 0);
    if (absent(im, bx, by, im.separate ? band : 0)) return e;  // no nodata: zeros
    const std::uint32_t rows = im.tiled ? bh : std::min(bh, im.h - by * bh);
    for (std::uint32_t y = 0; y < rows; ++y)
        for (std::uint32_t x = 0; x < bw; ++x)
            encodeSample(im.dt, sampleValue(im.level, band, std::uint64_t(bx) * bw + x, std::uint64_t(by) * bh + y),
                         hostLittle(), e.data() + (std::size_t(y) * bw + x) * size);
    return e;
}

// Open `bytes` and compare every block of every readable image with the specification.
static void checkAgainstSpec(const FileSpec& spec, const std::vector<std::uint8_t>& bytes) {
    Reader r;
    const Status s = r.open(bytes.data(), bytes.size());
    CHECK(s == Status::Ok);
    if (s != Status::Ok) {
        std::printf("  open: %s: %s\n", geotiff::statusName(s), r.message());
        return;
    }
    CHECK(r.isOpen());
    CHECK(r.bigTiff() == spec.big);
    CHECK(r.littleEndian() == spec.le);
    CHECK(r.imageCount() == spec.images.size());
    for (std::size_t i = 0; i < spec.images.size(); ++i) {
        const ImageSpec& im = spec.images[i];
        const geotiff::ImageInfo& in = r.image(i);
        if (in.status != Status::Ok) continue;
        const std::uint32_t bw = im.tiled ? im.bw : im.w;
        const std::uint32_t bh = im.tiled ? im.bh : std::min(im.bh, im.h);
        CHECK(in.width == im.w && in.height == im.h);
        CHECK(in.blockWidth == bw && in.blockHeight == bh);
        CHECK(in.blocksX == (im.w + bw - 1) / bw && in.blocksY == (im.h + bh - 1) / bh);
        CHECK(in.bands == im.bands);
        CHECK(in.dataType == im.dt);
        CHECK(in.bitsPerSample == geotiff::dataTypeSize(im.dt) * 8);
        CHECK(in.tiled == im.tiled);
        CHECK(in.planarSeparate == (im.separate && im.bands > 1));
        CHECK(in.blockBytes == std::uint64_t(bw) * bh * geotiff::dataTypeSize(im.dt));
        std::vector<std::uint8_t> got(static_cast<std::size_t>(in.blockBytes));
        for (unsigned band = 0; band < im.bands; ++band)
            for (std::uint32_t by = 0; by < in.blocksY; ++by)
                for (std::uint32_t bx = 0; bx < in.blocksX; ++bx) {
                    const bool gone = absent(im, bx, by, im.separate ? band : 0);
                    std::fill(got.begin(), got.end(), std::uint8_t(0xA5));
                    const Status rs = r.readBlock(i, bx, by, band, got.data(), got.size());
                    CHECK(rs == (gone ? Status::Sparse : Status::Ok));
                    CHECK(r.blockPresent(i, bx, by, band) == !gone);
                    CHECK(got == expectedBlock(im, bx, by, band));
                }
    }
}

static const DataType kTypes[] = {DataType::UInt8,  DataType::Int8,  DataType::UInt16, DataType::Int16,
                                  DataType::UInt32, DataType::Int32, DataType::UInt64, DataType::Int64,
                                  DataType::Float32, DataType::Float64};

// --- tests ------------------------------------------------------------------------------

static void testMatrix() {
    int files = 0;
    for (int big = 0; big < 2; ++big)
        for (int le = 0; le < 2; ++le)
            for (int tiled = 0; tiled < 2; ++tiled)
                for (int planar = 0; planar < 3; ++planar)  // 1 band, 3 pixel-interleaved, 3 band-interleaved
                    for (DataType dt : kTypes)
                        for (int sparse = 0; sparse < 2; ++sparse) {
                            FileSpec f;
                            f.big = big != 0;
                            f.le = le != 0;
                            ImageSpec im;
                            im.tiled = tiled != 0;
                            if (!im.tiled) im.bh = 5;
                            im.bands = planar == 0 ? 1 : 3;
                            im.separate = planar == 2;
                            im.dt = dt;
                            im.sparse = sparse != 0;
                            f.images.push_back(im);
                            char name[128];
                            std::snprintf(name, sizeof name, "%s %s %s planar%d %s%s", big ? "bigtiff" : "classic",
                                          le ? "LE" : "BE", tiled ? "tiled" : "strips", planar,
                                          geotiff::dataTypeName(dt), sparse ? " sparse" : "");
                            g_context = name;
                            checkAgainstSpec(f, build(f));
                            ++files;
                        }
    g_context = "matrix";
    CHECK(files == 480);
}

static void testLayouts() {
    // One strip for the whole image (RowsPerStrip absent), 1-row strips, tiles larger than
    // the image, a single pixel.
    struct Case { const char* name; std::uint32_t w, h, bw, bh; bool tiled; bool noRows; };
    const Case cases[] = {{"one strip, no RowsPerStrip", 13, 7, 0, 7, false, true},
                          {"one strip, RowsPerStrip > height", 13, 7, 0, 1000, false, false},
                          {"1-row strips", 9, 6, 0, 1, false, false},
                          {"tile larger than image", 5, 3, 32, 16, true, false},
                          {"single pixel strip", 1, 1, 0, 1, false, false},
                          {"single pixel tile", 1, 1, 16, 16, true, false}};
    for (const Case& c : cases) {
        g_context = c.name;
        FileSpec f;
        ImageSpec im;
        im.w = c.w;
        im.h = c.h;
        im.tiled = c.tiled;
        im.bw = c.bw;
        im.bh = c.bh;
        im.bands = 2;
        im.dt = DataType::Int16;
        if (c.noRows) im.omit.push_back(278);
        f.images.push_back(im);
        checkAgainstSpec(f, build(f));
    }
    // BitsPerSample / SampleFormat given once for several bands; SampleFormat absent.
    g_context = "per-sample tags given once";
    FileSpec f;
    ImageSpec im;
    im.bands = 3;
    im.dt = DataType::UInt16;
    im.extra.push_back(ints(258, 3, {16}));
    im.omit.push_back(339);
    f.images.push_back(im);
    checkAgainstSpec(f, build(f));
}

// One stored strip is presented as GDAL presents it: virtual strips of <= 8192 bytes, or
// single rows for 8-bit images of more than 2000 rows.
static void testVirtualStrips() {
    struct Case { const char* name; std::uint32_t w, h; unsigned bands; bool separate; DataType dt;
                  bool absentStrip; std::uint32_t rows; };
    const Case cases[] = {
        {"chop 2 bands int16", 100, 50, 2, false, DataType::Int16, false, 20},
        {"chop absent", 100, 50, 2, false, DataType::Int16, true, 20},
        {"chop row > 8192", 3000, 3, 1, false, DataType::Float32, false, 1},
        {"no chop: exactly 8192", 64, 128, 1, false, DataType::UInt8, false, 128},
        {"no chop: band-interleaved", 100, 50, 3, true, DataType::Int16, false, 50},
        {"split band-interleaved", 5, 2001, 3, true, DataType::UInt8, false, 1},
        {"split absent", 5, 2001, 3, true, DataType::Int8, true, 1},
        {"split pixel-interleaved", 1, 2001, 3, false, DataType::UInt8, false, 1},
        {"no split: 2000 rows", 4, 2000, 1, false, DataType::UInt8, false, 2000},
        {"no split: 16 bit", 3, 2001, 3, true, DataType::UInt16, false, 2001},
    };
    for (const Case& c : cases) {
        g_context = std::string("virtual strips: ") + c.name;
        FileSpec stored;
        ImageSpec im;
        im.w = c.w; im.h = c.h; im.tiled = false; im.bh = c.h; im.bands = c.bands; im.separate = c.separate;
        im.dt = c.dt; im.allAbsent = c.absentStrip;
        stored.images.push_back(im);
        const std::vector<std::uint8_t> bytes = build(stored);
        FileSpec shown = stored;       // what the reader must present
        shown.images[0].bh = c.rows;
        Reader r;
        CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
        const geotiff::ImageInfo& in = r.image();
        CHECK(in.blockHeight == c.rows && in.blocksY == (c.h + c.rows - 1) / c.rows);
        CHECK(in.blockBytes == std::uint64_t(c.w) * c.rows * geotiff::dataTypeSize(c.dt));
        std::vector<std::uint8_t> got(static_cast<std::size_t>(in.blockBytes));
        bool same = in.blockHeight == c.rows;
        for (unsigned band = 0; same && band < c.bands; ++band)
            for (std::uint32_t by = 0; by < in.blocksY; ++by) {
                const Status s = r.readBlock(0, 0, by, band, got.data(), got.size());
                same = same && s == (c.absentStrip ? Status::Sparse : Status::Ok) &&
                       r.blockPresent(0, 0, by, band) == !c.absentStrip &&
                       got == expectedBlock(shown.images[0], 0, by, band);
            }
        CHECK(same);
    }
    {
        g_context = "virtual strips: truncated strip";
        FileSpec f;
        ImageSpec im;
        im.w = 5; im.h = 2001; im.tiled = false; im.bh = 2001; im.bands = 2; im.separate = true;
        im.countCut = 5 * 2001 - 12;  // 12 bytes stored per band
        f.images.push_back(im);
        const std::vector<std::uint8_t> bytes = build(f);
        Reader r;
        unsigned char row[5];
        CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
        CHECK(r.readBlock(0, 0, 1, 0, row, sizeof row) == Status::Ok);
        CHECK(r.readBlock(0, 0, 2, 0, row, sizeof row) == Status::Corrupt);   // 2 of 5 bytes left
        CHECK(r.readBlock(0, 0, 3, 0, row, sizeof row) == Status::Corrupt);   // beyond the strip
        CHECK(std::strstr(r.message(), "beyond the stored strip") != nullptr);
    }
}

static bool near(double a, double b) { return std::fabs(a - b) <= 1e-9 * (1.0 + std::fabs(b)); }

static void testGeo() {
    auto open = [](const std::vector<Field>& extra, Reader& r) {
        FileSpec f;
        ImageSpec im;
        im.extra = extra;
        f.images.push_back(im);
        const std::vector<std::uint8_t> bytes = build(f);
        return r.open(bytes.data(), bytes.size());  // open() copies what it keeps
    };
    {
        g_context = "geo: none";
        Reader r;
        CHECK(open({}, r) == Status::Ok);
        CHECK(!r.geo().hasGeoTransform && !r.geo().hasNoData && r.geo().epsg == 0 && !r.geo().pixelIsPoint);
        CHECK(std::strcmp(r.noDataText(), "") == 0 && std::strcmp(r.gdalMetadata(), "") == 0);
        std::uint16_t v = 0;
        CHECK(!r.geoKey(3072, v));
    }
    {
        g_context = "geo: scale + tiepoint, projected, area";
        Reader r;
        CHECK(open({doubles(33550, {2.5, 2.5, 0}), doubles(33922, {0, 0, 0, 500000, 4649776, 0}),
                    ints(34735, 3, {1, 1, 0, 3, 1024, 0, 1, 1, 1025, 0, 1, 1, 3072, 0, 1, 32632}),
                    ascii(42112, "<GDALMetadata><Item name=\"a\">b</Item></GDALMetadata>"),
                    ascii(42113, "-9999")}, r) == Status::Ok);
        const geotiff::GeoInfo& g = r.geo();
        CHECK(g.hasGeoTransform);
        CHECK(near(g.geoTransform[0], 500000) && near(g.geoTransform[1], 2.5) && g.geoTransform[2] == 0);
        CHECK(near(g.geoTransform[3], 4649776) && g.geoTransform[4] == 0 && near(g.geoTransform[5], -2.5));
        CHECK(!g.pixelIsPoint && g.modelType == 1 && g.epsg == 32632);
        CHECK(g.hasNoData && g.noData == -9999.0);
        CHECK(std::strcmp(r.noDataText(), "-9999") == 0);
        CHECK(std::strstr(r.gdalMetadata(), "<Item name=\"a\">b</Item>") != nullptr);
        std::uint16_t v = 0;
        CHECK(r.geoKey(3072, v) && v == 32632);
        CHECK(!r.geoKey(2048, v));
    }
    {
        g_context = "geo: tiepoint off the origin, geographic, point";
        Reader r;
        CHECK(open({doubles(33550, {0.5, 0.25, 0}), doubles(33922, {10, 20, 0, 8.0, 50.0, 0}),
                    ints(34735, 3, {1, 1, 0, 3, 1024, 0, 1, 2, 1025, 0, 1, 2, 2048, 0, 1, 4326})}, r) == Status::Ok);
        const geotiff::GeoInfo& g = r.geo();
        CHECK(g.hasGeoTransform && g.pixelIsPoint && g.modelType == 2 && g.epsg == 4326);
        CHECK(near(g.geoTransform[0], 8.0 - 10 * 0.5 - 0.25) && near(g.geoTransform[1], 0.5));
        CHECK(near(g.geoTransform[3], 50.0 + 20 * 0.25 + 0.125) && near(g.geoTransform[5], -0.25));
    }
    {
        g_context = "geo: transformation matrix, user-defined CRS";
        Reader r;
        CHECK(open({doubles(34264, {2, 0.5, 0, 1000, -0.5, -2, 0, 2000, 0, 0, 0, 0, 0, 0, 0, 1}),
                    ints(34735, 3, {1, 1, 0, 2, 1024, 0, 1, 1, 3072, 0, 1, 32767})}, r) == Status::Ok);
        const geotiff::GeoInfo& g = r.geo();
        CHECK(g.hasGeoTransform && !g.pixelIsPoint && g.epsg == 0);
        CHECK(g.geoTransform[0] == 1000 && g.geoTransform[1] == 2 && g.geoTransform[2] == 0.5);
        CHECK(g.geoTransform[3] == 2000 && g.geoTransform[4] == -0.5 && g.geoTransform[5] == -2);
    }
    {
        g_context = "geo: key directory announcing more keys than it holds";
        Reader r;
        CHECK(open({ints(34735, 3, {1, 1, 0, 500, 1024, 0, 1, 2, 2048, 0, 1, 4258})}, r) == Status::Ok);
        CHECK(r.geo().epsg == 4258);
    }
}

template <typename T>
static void noDataCase(DataType dt, const char* text, T expected, bool expectNaN = false) {
    g_context = std::string("nodata ") + geotiff::dataTypeName(dt) + " '" + text + "'";
    FileSpec f;
    ImageSpec im;
    im.dt = dt;
    im.allAbsent = true;
    im.w = im.h = 16;
    im.extra.push_back(ascii(42113, text));
    f.images.push_back(im);
    const std::vector<std::uint8_t> bytes = build(f);
    Reader r;
    CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
    std::vector<T> block(16 * 16);
    CHECK(r.image().blockBytes == block.size() * sizeof(T));
    CHECK(r.readBlock(0, 0, 0, 0, block.data(), block.size() * sizeof(T)) == Status::Sparse);
    CHECK(!r.blockPresent(0, 0, 0, 0));
    bool all = true;
    for (T v : block) all = all && (expectNaN ? v != v : v == expected);
    CHECK(all);
}

static void testNoData() {
    noDataCase<std::uint8_t>(DataType::UInt8, "-9999", 0);
    noDataCase<std::uint8_t>(DataType::UInt8, "255", 255);
    noDataCase<std::uint8_t>(DataType::UInt8, "3.7", 4);
    noDataCase<std::uint8_t>(DataType::UInt8, "1e10", 255);
    noDataCase<std::int8_t>(DataType::Int8, "-128", -128);
    noDataCase<std::int16_t>(DataType::Int16, "-9999", -9999);
    noDataCase<std::int16_t>(DataType::Int16, "1e10", 32767);
    noDataCase<std::int16_t>(DataType::Int16, "-2.5", -3);
    noDataCase<std::uint16_t>(DataType::UInt16, "nan", 0);
    noDataCase<std::uint16_t>(DataType::UInt16, "65535", 65535);
    noDataCase<std::int32_t>(DataType::Int32, "-2147483648", INT32_MIN);
    noDataCase<std::uint32_t>(DataType::UInt32, "4294967295", UINT32_MAX);
    noDataCase<std::int64_t>(DataType::Int64, "-9223372036854775808", INT64_MIN);
    noDataCase<std::int64_t>(DataType::Int64, "9223372036854775807", INT64_MAX);
    noDataCase<std::int64_t>(DataType::Int64, "-1.5e3", -1500);
    noDataCase<std::uint64_t>(DataType::UInt64, "18446744073709551615", UINT64_MAX);
    noDataCase<std::uint64_t>(DataType::UInt64, "-5", 0);
    noDataCase<std::uint64_t>(DataType::UInt64, "1e30", UINT64_MAX);
    noDataCase<float>(DataType::Float32, "-9999.5", -9999.5f);
    noDataCase<float>(DataType::Float32, "nan", 0.0f, true);
    noDataCase<float>(DataType::Float32, "1e300", std::numeric_limits<float>::infinity());
    noDataCase<float>(DataType::Float32, "-1e300", -std::numeric_limits<float>::infinity());
    noDataCase<double>(DataType::Float64, "1.5e300", 1.5e300);
    noDataCase<double>(DataType::Float64, "-inf", -std::numeric_limits<double>::infinity());
    noDataCase<double>(DataType::Float64, "nan", 0.0, true);
    noDataCase<double>(DataType::Float64, "not a number", 0.0);  // unparsable: treated as no nodata
}

static void testOverviews() {
    g_context = "overviews + mask";
    FileSpec f;
    f.big = true;
    f.le = false;
    ImageSpec main;
    main.bands = 3;
    main.dt = DataType::Float32;
    main.sparse = true;
    ImageSpec ov1 = main, ov2 = main, mask;
    ov1.w = 20; ov1.h = 19; ov1.subfile = 1; ov1.level = 1;
    ov2.w = 10; ov2.h = 10; ov2.subfile = 1; ov2.level = 2; ov2.tiled = false; ov2.bh = 4; ov2.separate = true;
    mask.subfile = 4; mask.compression = 8;       // like GDAL's internal mask: 1-bit DEFLATE
    mask.extra.push_back(ints(258, 3, {1}));
    f.images = {main, ov1, mask, ov2};
    const std::vector<std::uint8_t> bytes = build(f);
    checkAgainstSpec(f, bytes);
    Reader r;
    CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
    CHECK(r.imageCount() == 4);
    CHECK(!r.image(0).overview && !r.image(0).mask);
    CHECK(r.image(1).overview && r.image(3).overview);
    CHECK(r.image(2).mask && r.image(2).status == Status::Unsupported);
    CHECK(std::strstr(r.imageMessage(2), "DEFLATE") != nullptr);
    CHECK(std::strcmp(r.imageMessage(0), "") == 0);
    CHECK(r.overviewCount() == 2);
    CHECK(r.overviewImage(0) == 1 && r.overviewImage(1) == 3 && r.overviewImage(2) == r.imageCount());
    unsigned char one[4];
    CHECK(r.readBlock(2, 0, 0, 0, one, sizeof one) == Status::Unsupported);
    CHECK(std::strstr(r.message(), "DEFLATE") != nullptr);
    CHECK(!r.blockPresent(2, 0, 0, 0));
}

static void testUnsupported() {
    struct Case { std::uint16_t compression; const char* name; };
    const Case cases[] = {{5, "LZW"}, {7, "JPEG"}, {8, "DEFLATE"}, {32946, "DEFLATE"}, {32773, "PackBits"},
                          {34887, "LERC"}, {34925, "LZMA"}, {50000, "ZSTD"}, {50001, "WebP"}, {4, "CCITT"},
                          {12345, "unknown"}};
    for (const Case& c : cases) {
        g_context = std::string("unsupported compression ") + c.name;
        FileSpec f;
        ImageSpec im;
        im.compression = c.compression;
        f.images.push_back(im);
        const std::vector<std::uint8_t> bytes = build(f);
        Reader r;
        CHECK(r.open(bytes.data(), bytes.size()) == Status::Unsupported);
        CHECK(!r.isOpen() && r.imageCount() == 0);
        CHECK(std::strstr(r.message(), c.name) != nullptr);
        CHECK(std::strstr(r.message(), "compression") != nullptr);
    }
    auto openStatus = [](const ImageSpec& im, std::string& message) {
        FileSpec f;
        f.images.push_back(im);
        const std::vector<std::uint8_t> bytes = build(f);
        Reader r;
        const Status s = r.open(bytes.data(), bytes.size());
        message = r.message();
        return s;
    };
    std::string m;
    {
        g_context = "unsupported predictor";
        ImageSpec im;
        im.predictor = 2;
        CHECK(openStatus(im, m) == Status::Unsupported && m.find("predictor 2") != std::string::npos);
    }
    {
        g_context = "unsupported bit depth";
        ImageSpec im;
        im.extra.push_back(ints(258, 3, {12}));
        CHECK(openStatus(im, m) == Status::Unsupported && m.find("12-bit") != std::string::npos);
    }
    {
        g_context = "unsupported: complex samples";
        ImageSpec im;
        im.dt = DataType::Float32;
        im.extra.push_back(ints(339, 3, {6}));
        CHECK(openStatus(im, m) == Status::Unsupported);
    }
    {
        g_context = "unsupported: 16-bit float";
        ImageSpec im;
        im.dt = DataType::Float32;
        im.extra.push_back(ints(258, 3, {16}));
        CHECK(openStatus(im, m) == Status::Unsupported);
    }
    {
        g_context = "unsupported: mixed bit depths";
        ImageSpec im;
        im.bands = 3;
        im.extra.push_back(ints(258, 3, {8, 8, 16}));
        CHECK(openStatus(im, m) == Status::Unsupported);
    }
    {
        g_context = "unsupported: YCbCr";
        ImageSpec im;
        im.bands = 3;
        im.extra.push_back(ints(262, 3, {6}));
        CHECK(openStatus(im, m) == Status::Unsupported && m.find("YCbCr") != std::string::npos);
    }
    {
        g_context = "compressed overview: main image stays readable";
        FileSpec f;
        ImageSpec main, ov;
        ov.subfile = 1;
        ov.compression = 5;
        f.images = {main, ov};
        const std::vector<std::uint8_t> bytes = build(f);
        checkAgainstSpec(f, bytes);
        Reader r;
        CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
        CHECK(r.image(1).status == Status::Unsupported && r.image(1).compression == 5);
    }
}

static void testApi() {
    g_context = "api";
    FileSpec f;
    ImageSpec im;
    im.bands = 2;
    im.dt = DataType::UInt16;
    f.images.push_back(im);
    const std::vector<std::uint8_t> bytes = build(f);
    std::vector<std::uint8_t> buffer(16 * 16 * 2);

    Reader r;
    CHECK(!r.isOpen() && r.imageCount() == 0 && std::strcmp(r.message(), "") == 0);
    CHECK(r.readBlock(0, 0, 0, 0, buffer.data(), buffer.size()) == Status::NotOpen);
    CHECK(r.image(0).width == 0 && r.image(7).blockBytes == 0);
    CHECK(r.overviewCount() == 0);

    CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
    CHECK(std::strcmp(r.message(), "") == 0);
    CHECK(r.readBlock(0, 0, 0, 0, buffer.data(), buffer.size()) == Status::Ok);
    CHECK(r.readBlock(1, 0, 0, 0, buffer.data(), buffer.size()) == Status::OutOfRange);
    CHECK(r.readBlock(0, 3, 0, 0, buffer.data(), buffer.size()) == Status::OutOfRange);
    CHECK(r.readBlock(0, 0, 3, 0, buffer.data(), buffer.size()) == Status::OutOfRange);
    CHECK(r.readBlock(0, 0, 0, 2, buffer.data(), buffer.size()) == Status::OutOfRange);
    CHECK(std::strstr(r.message(), "out of range") != nullptr);
    CHECK(r.readBlock(0, 0, 0, 0, buffer.data(), buffer.size() - 1) == Status::BufferTooSmall);
    CHECK(r.readBlock(0, 0, 0, 0, nullptr, buffer.size()) == Status::BufferTooSmall);
    CHECK(!r.blockPresent(0, 3, 0, 0) && !r.blockPresent(5, 0, 0, 0) && r.blockPresent(0, 2, 2, 1));
    std::uint64_t offset = 0, count = 0;
    CHECK(r.blockLocation(0, 1, 1, 0, offset, count) == Status::Ok);
    CHECK(offset != 0 && count == 16u * 16 * 2 * 2);
    CHECK(r.blockLocation(0, 9, 9, 0, offset, count) == Status::OutOfRange);
    CHECK(geotiff::ok(Status::Ok) && geotiff::ok(Status::Sparse) && !geotiff::ok(Status::Corrupt));
    CHECK(std::strcmp(geotiff::statusName(Status::Unsupported), "Unsupported") == 0);
    CHECK(std::strcmp(geotiff::dataTypeName(DataType::UInt8), "Byte") == 0);

    r.close();
    CHECK(!r.isOpen() && r.readBlock(0, 0, 0, 0, buffer.data(), buffer.size()) == Status::NotOpen);

    // By path, and reopening the same Reader on another file.
    const char* path = "geotiff_test_tmp.tif";
    std::FILE* file = std::fopen(path, "wb");
    CHECK(file != nullptr);
    if (file != nullptr) {
        CHECK(std::fwrite(bytes.data(), 1, bytes.size(), file) == bytes.size());
        std::fclose(file);
        CHECK(r.open(path) == Status::Ok);
        CHECK(r.readBlock(0, 2, 2, 1, buffer.data(), buffer.size()) == Status::Ok);
        CHECK(buffer == expectedBlock(im, 2, 2, 1));
        CHECK(r.open(bytes.data(), bytes.size()) == Status::Ok);
        CHECK(r.readBlock(0, 1, 0, 0, buffer.data(), buffer.size()) == Status::Ok);
        CHECK(buffer == expectedBlock(im, 1, 0, 0));
        std::remove(path);
    }
    CHECK(r.open("no/such/file.tif") == Status::Io);
    CHECK(!r.isOpen() && std::strstr(r.message(), "no/such/file.tif") != nullptr);
    CHECK(r.open(static_cast<const char*>(nullptr)) == Status::Io);

    // Caller-owned source; one that starts failing gives Status::Io, not a crash.
    struct Flaky final : geotiff::Source {
        geotiff::MemorySource inner;
        long budget = -1;  // reads left before failing; -1 = never fail
        std::uint64_t size() const noexcept override { return inner.size(); }
        bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept override {
            if (budget == 0) return false;
            if (budget > 0) --budget;
            return inner.readAt(offset, dst, size);
        }
    };
    Flaky flaky;
    flaky.inner = geotiff::MemorySource(bytes.data(), bytes.size());
    CHECK(r.open(flaky) == Status::Ok);
    CHECK(r.readBlock(0, 0, 0, 1, buffer.data(), buffer.size()) == Status::Ok);
    CHECK(buffer == expectedBlock(im, 0, 0, 1));
    flaky.budget = 0;
    CHECK(r.readBlock(0, 1, 0, 0, buffer.data(), buffer.size()) == Status::Io);
    for (long budget = 0; budget < 40; ++budget) {
        flaky.budget = budget;
        const Status s = r.open(flaky);
        CHECK(s == Status::Io || s == Status::Ok);
    }
}

// Open arbitrary bytes and read what can be read: must return, with any status.
static void exercise(const std::uint8_t* data, std::size_t size) {
    Reader r;
    const Status s = r.open(data, size);
    if (s != Status::Ok) {
        CHECK(!r.isOpen() && r.message()[0] != '\0');
        return;
    }
    std::vector<std::uint8_t> buffer;
    for (std::size_t i = 0; i < r.imageCount(); ++i) {
        const geotiff::ImageInfo in = r.image(i);
        unsigned char tiny[1];
        if (in.status != Status::Ok) {
            CHECK(r.readBlock(i, 0, 0, 0, tiny, 1) == Status::Unsupported);
            continue;
        }
        if (in.blockBytes > (1u << 16)) {
            CHECK(r.readBlock(i, 0, 0, 0, tiny, 1) == Status::BufferTooSmall);
            continue;
        }
        buffer.resize(static_cast<std::size_t>(in.blockBytes));
        unsigned reads = 0;
        for (unsigned band = 0; band < in.bands && band < 4; ++band)
            for (std::uint32_t by = 0; by < in.blocksY; ++by)
                for (std::uint32_t bx = 0; bx < in.blocksX && reads < 256; ++bx, ++reads)
                    (void)r.readBlock(i, bx, by, band, buffer.data(), buffer.size());
    }
    ++g_checks;
}

static void testCorrupt() {
    auto openStatus = [](const std::vector<std::uint8_t>& bytes, std::string& message) {
        Reader r;
        const Status s = r.open(bytes.data(), bytes.size());
        message = r.message();
        return s;
    };
    std::string m;
    FileSpec base;
    base.images.push_back(ImageSpec());
    {
        g_context = "corrupt: header";
        std::vector<std::uint8_t> b = build(base);
        CHECK(openStatus({}, m) == Status::NotTiff);
        CHECK(openStatus({'I', 'I', 42, 0}, m) == Status::NotTiff);
        std::vector<std::uint8_t> c = b;
        c[0] = 'X';
        CHECK(openStatus(c, m) == Status::NotTiff);
        c = b;
        c[2] = 99;
        CHECK(openStatus(c, m) == Status::NotTiff);
        c = b;
        c[4] = c[5] = c[6] = c[7] = 0;
        CHECK(openStatus(c, m) == Status::Corrupt);
        c = b;
        c[4] = c[5] = c[6] = c[7] = 0xFF;
        CHECK(openStatus(c, m) == Status::Corrupt);
        FileSpec big = base;
        big.big = true;
        c = build(big);
        c[4] = 4;  // offset size
        CHECK(openStatus(c, m) == Status::Corrupt);
    }
    {
        g_context = "corrupt: IFD chain loop";
        FileSpec f = base;
        f.loop = true;
        CHECK(openStatus(build(f), m) == Status::Corrupt && m.find("loop") != std::string::npos);
    }
    {
        g_context = "corrupt: fields";
        FileSpec f = base;
        f.images[0].extra = {ints(256, 4, {0})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].omit = {257};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].omit = {325};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].omit = {323};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(322, 4, {0})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(284, 3, {3})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(277, 3, {0})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(324, 4, {8, 8})};  // 9 tiles, table of 2
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {doubles(256, {40.0})};  // width as DOUBLE
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].tiled = false;
        f.images[0].extra = {ints(278, 4, {0})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(42113, 3, {1})};  // nodata not ASCII
        CHECK(openStatus(build(f), m) == Status::Corrupt);
        f = base;
        f.images[0].extra = {ints(33550, 4, {1, 1, 1}), doubles(33922, {0, 0, 0, 0, 0, 0})};
        CHECK(openStatus(build(f), m) == Status::Corrupt);
    }
    {
        g_context = "corrupt: block outside the file / too short";
        std::vector<std::uint8_t> buffer(16 * 16 * 3);
        for (int bands = 1; bands <= 3; bands += 2) {
            FileSpec f = base;
            f.images[0].bands = static_cast<unsigned>(bands);
            f.images[0].offsetBias = 1 << 20;
            std::vector<std::uint8_t> b = build(f);
            Reader r;
            CHECK(r.open(b.data(), b.size()) == Status::Ok);
            CHECK(r.readBlock(0, 0, 0, 0, buffer.data(), buffer.size()) == Status::Corrupt);
            CHECK(std::strstr(r.message(), "outside the file") != nullptr);
            f.images[0].offsetBias = 0;
            f.images[0].countCut = 1;
            b = build(f);
            CHECK(r.open(b.data(), b.size()) == Status::Ok);
            CHECK(r.readBlock(0, 1, 1, 0, buffer.data(), buffer.size()) == Status::Corrupt);
            CHECK(std::strstr(r.message(), "expected") != nullptr);
        }
    }

    // Every truncation and a set of byte mutations at every position of three files:
    // any status is fine, crashes and sanitizer reports are not.
    std::vector<FileSpec> files;
    {
        FileSpec a;  // classic LE, tiled, pixel-interleaved, georeferenced, sparse, overview
        ImageSpec im;
        im.w = 20; im.h = 18; im.bands = 2; im.dt = DataType::UInt16; im.sparse = true;
        im.extra = {doubles(33550, {2.5, 2.5, 0}), doubles(33922, {0, 0, 0, 500000, 4649776, 0}),
                    ints(34735, 3, {1, 1, 0, 3, 1024, 0, 1, 1, 1025, 0, 1, 1, 3072, 0, 1, 32632}),
                    ascii(42112, "<GDALMetadata></GDALMetadata>"), ascii(42113, "-9999")};
        ImageSpec ov = im;
        ov.w = 10; ov.h = 9; ov.subfile = 1; ov.extra.clear();
        a.images = {im, ov};
        files.push_back(a);
        FileSpec b;  // BigTIFF BE, strips, band-interleaved
        b.big = true;
        b.le = false;
        ImageSpec st;
        st.w = 11; st.h = 9; st.tiled = false; st.bh = 4; st.bands = 3; st.separate = true; st.dt = DataType::Float64;
        b.images = {st};
        files.push_back(b);
        FileSpec c;  // classic BE, strips, single band
        c.le = false;
        ImageSpec sb;
        sb.w = 7; sb.h = 5; sb.tiled = false; sb.bh = 2; sb.dt = DataType::Int32;
        sb.extra = {doubles(34264, {2, 0.5, 0, 1000, -0.5, -2, 0, 2000, 0, 0, 0, 0, 0, 0, 0, 1})};
        c.images = {sb};
        files.push_back(c);
    }
    for (std::size_t k = 0; k < files.size(); ++k) {
        const std::vector<std::uint8_t> good = build(files[k]);
        g_context = "fuzz file " + std::to_string(k);
        checkAgainstSpec(files[k], good);
        for (std::size_t n = 0; n < good.size(); ++n) {
            const std::vector<std::uint8_t> cut(good.begin(), good.begin() + static_cast<std::ptrdiff_t>(n));
            exercise(cut.data(), cut.size());
        }
        std::vector<std::uint8_t> bad = good;
        for (std::size_t i = 0; i < good.size(); ++i) {
            const std::uint8_t o = good[i];
            const std::uint8_t values[] = {0, 1, 0xFF, static_cast<std::uint8_t>(o ^ 0x80),
                                           static_cast<std::uint8_t>(o + 1), static_cast<std::uint8_t>(o - 1)};
            for (std::uint8_t v : values) {
                if (v == o) continue;
                bad[i] = v;
                exercise(bad.data(), bad.size());
            }
            bad[i] = o;
        }
        // Two-byte mutations with a fixed pseudo-random sequence.
        std::uint32_t seed = 12345u + static_cast<std::uint32_t>(k);
        auto next = [&seed]() { seed = seed * 1664525u + 1013904223u; return seed >> 8; };
        for (int round = 0; round < 20000; ++round) {
            const std::size_t i = next() % good.size(), j = next() % good.size();
            bad[i] = static_cast<std::uint8_t>(next());
            bad[j] = static_cast<std::uint8_t>(next());
            exercise(bad.data(), bad.size());
            bad[i] = good[i];
            bad[j] = good[j];
        }
    }
}

int main() {
    testMatrix();
    testLayouts();
    testVirtualStrips();
    testGeo();
    testNoData();
    testOverviews();
    testUnsupported();
    testApi();
    testCorrupt();
    std::printf("geotiff_test: %ld checks, %ld failed\n", g_checks, g_failed);
    return g_failed == 0 ? 0 : 1;
}
