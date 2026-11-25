// geotiff.cpp — implementation of geotiff.h: the TIFF container, the project constraints,
// tile access and the GeoTIFF / GDAL tags. Background: llm/knowledge.md.
//
// SPDX-License-Identifier: MIT
#include "geotiff/geotiff.h"

#include <cstdarg>
#include <cstdlib>
#include <cstring>
#include <limits>

// The reader copies file bytes straight into samples and tag values.
#if !defined(__BYTE_ORDER__) || __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
#error "geotiff needs a little-endian host"
#endif

namespace geotiff {

namespace {

// TIFF, GeoTIFF and GDAL tags the reader uses.
enum : std::uint16_t {
    kImageWidth = 256, kImageLength = 257, kBitsPerSample = 258,
    kCompression = 259, kPhotometric = 262, kSamplesPerPixel = 277, kPlanarConfig = 284,
    kPredictor = 317,
    kTileWidth = 322, kTileLength = 323, kTileOffsets = 324, kTileByteCounts = 325,
    kSampleFormat = 339, kModelPixelScale = 33550, kModelTiepoint = 33922,
    kModelTransformation = 34264, kGeoKeyDirectory = 34735, kGdalMetadata = 42112,
    kGdalNoData = 42113
};

bool mulOverflow(std::uint64_t a, std::uint64_t b, std::uint64_t& r) noexcept {
    if (a != 0 && b > std::numeric_limits<std::uint64_t>::max() / a) return true;
    r = a * b;
    return false;
}

// Little-endian integers of the file structure.
std::uint16_t rd16(const unsigned char* p) noexcept {
    return static_cast<std::uint16_t>(p[0] | (p[1] << 8));
}

std::uint32_t rd32(const unsigned char* p) noexcept {
    return static_cast<std::uint32_t>(p[0]) | static_cast<std::uint32_t>(p[1]) << 8 |
           static_cast<std::uint32_t>(p[2]) << 16 | static_cast<std::uint32_t>(p[3]) << 24;
}

std::uint64_t rd64(const unsigned char* p) noexcept {
    return static_cast<std::uint64_t>(rd32(p + 4)) << 32 | rd32(p);
}

bool parseDouble(const char* text, double& value) noexcept {
    char* end = nullptr;
    value = std::strtod(text, &end);
    if (end == text) return false;
    if (*end == '.') {  // a locale with another decimal separator is active
        char copy[64];
        std::size_t n = 0;
        for (; text[n] != '\0' && n + 1 < sizeof copy; ++n)
            copy[n] = text[n] == '.' ? ',' : text[n];
        copy[n] = '\0';
        value = std::strtod(copy, &end);
        if (end == copy) return false;
    }
    return true;
}

unsigned typeSize(std::uint16_t type) noexcept {
    switch (type) {
        case 1: case 2: case 6: case 7: return 1;       // BYTE ASCII SBYTE UNDEFINED
        case 3: case 8: return 2;                       // SHORT SSHORT
        case 4: case 9: case 11: case 13: return 4;     // LONG SLONG FLOAT IFD
        case 5: case 10: case 12: case 16: case 17: case 18: return 8;  // (S)RATIONAL DOUBLE LONG8 SLONG8 IFD8
        default: return 0;
    }
}

const char* compressionName(std::uint64_t c) noexcept {
    switch (c) {
        case 2: return "CCITT RLE";
        case 3: return "CCITT Group 3";
        case 4: return "CCITT Group 4";
        case 5: return "LZW";
        case 6: case 7: return "JPEG";
        case 8: case 32946: return "DEFLATE";
        case 32773: return "PackBits";
        case 34712: return "JPEG 2000";
        case 34887: return "LERC";
        case 34925: return "LZMA";
        case 50000: return "ZSTD";
        case 50001: return "WebP";
        case 50002: case 52546: return "JPEG XL";
        default: return "unknown";
    }
}

}  // namespace

// ---------------------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------------------

const char* statusName(Status s) noexcept {
    switch (s) {
        case Status::Ok: return "Ok";
        case Status::Sparse: return "Sparse";
        case Status::Io: return "Io";
        case Status::NotTiff: return "NotTiff";
        case Status::Corrupt: return "Corrupt";
        case Status::Unsupported: return "Unsupported";
        case Status::OutOfRange: return "OutOfRange";
        case Status::BufferTooSmall: return "BufferTooSmall";
        case Status::OutOfMemory: return "OutOfMemory";
        case Status::NotOpen: return "NotOpen";
    }
    return "?";
}

const char* dataTypeName(DataType t) noexcept {
    switch (t) {
        case DataType::UInt8: return "Byte";
        case DataType::UInt16: return "UInt16";
        case DataType::Int16: return "Int16";
        case DataType::Unknown: break;
    }
    return "Unknown";
}

// ---------------------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------------------

bool MemorySource::readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept {
    if (offset > size_ || size > size_ - offset) return false;
    if (size != 0) std::memcpy(dst, data_ + offset, size);
    return true;
}

bool FileSource::open(const char* path) noexcept {
    close();
    if (path == nullptr) return false;
    file_ = std::fopen(path, "rb");
    if (file_ == nullptr) return false;
    std::int64_t end = -1;
    if (seek(0, SEEK_END)) end = tell();
    if (end < 0) {
        close();
        return false;
    }
    size_ = static_cast<std::uint64_t>(end);
    return true;
}

void FileSource::close() noexcept {
    if (file_ != nullptr) std::fclose(file_);
    file_ = nullptr;
    size_ = 0;
}

bool FileSource::readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept {
    if (file_ == nullptr || offset > size_ || size > size_ - offset) return false;
    if (size == 0) return true;
    if (!seek(offset, SEEK_SET)) return false;
    return std::fread(dst, 1, size, file_) == size;
}

// Standard fseek/ftell: the offset is a long, 64 bit on 64-bit Linux (the target). Where long
// is 32 bit (Windows, 32-bit systems) offsets past 2 GB fail here instead of wrapping.
bool FileSource::seek(std::uint64_t offset, int whence) noexcept {
    if (offset > static_cast<std::uint64_t>(std::numeric_limits<long>::max())) return false;
    return std::fseek(file_, static_cast<long>(offset), whence) == 0;
}

std::int64_t FileSource::tell() noexcept { return static_cast<std::int64_t>(std::ftell(file_)); }

// ---------------------------------------------------------------------------------------
// Reader
// ---------------------------------------------------------------------------------------

struct Reader::Entry {
    std::uint16_t tag;
    std::uint16_t type;
    std::uint64_t count;
    const unsigned char* value;  // the 4 / 8 value-or-offset bytes of the entry
};

struct Reader::Ifd {
    unsigned char* raw = nullptr;
    std::uint64_t count = 0;
    ~Ifd() { std::free(raw); }
};

// Open a file by path.
Status Reader::open(const char* path) noexcept {
    close();
    if (!file_.open(path)) return fail(Status::Io, "cannot open '%s'", path ? path : "(null)");
    return openSource(file_);
}

// Open a file image held in memory; the bytes must outlive the Reader's use of them.
Status Reader::open(const void* data, std::size_t size) noexcept {
    close();
    memory_ = MemorySource(data, size);
    return openSource(memory_);
}

// Open on a caller-owned source (mmap, custom file system, ...).
Status Reader::open(Source& source) noexcept {
    close();
    return openSource(source);
}

void Reader::close() noexcept {
    release();
    message_[0] = '\0';
}

// A GeoKey stored as a SHORT in the GeoKey directory (e.g. 3072 ProjectedCSType).
bool Reader::geoKey(std::uint16_t id, std::uint16_t& value) const noexcept {
    if (geoKeyCount_ < 4) return false;
    std::size_t keys = geoKeys_[3];
    if (keys > (geoKeyCount_ - 4) / 4) keys = (geoKeyCount_ - 4) / 4;
    for (std::size_t k = 0; k < keys; ++k) {
        const std::uint16_t* e = geoKeys_ + 4 + 4 * k;
        if (e[0] == id && e[1] == 0) {
            value = e[3];
            return true;
        }
    }
    return false;
}

// False for an absent (sparse) tile and for an index out of range.
bool Reader::blockPresent(std::uint32_t bx, std::uint32_t by) const noexcept {
    if (bx >= info_.blocksX || by >= info_.blocksY) return false;
    const std::uint64_t tile = tileIndex(bx, by);
    return offsets_[tile] != 0 && counts_[tile] != 0;
}

// Read tile (bx, by) of `band` (0-based) into `buffer` (>= ImageInfo::blockBytes):
// kTileSize x kTileSize samples of that band, row by row — the same bytes GDAL's
// ReadBlock gives.
//   Status::Ok      tile read from the file
//   Status::Sparse  tile absent: buffer filled with the nodata value, or 0
//   anything else   failure, buffer contents unspecified
Status Reader::readBlock(std::uint32_t bx, std::uint32_t by, unsigned band, void* buffer,
                         std::size_t bufferSize) noexcept {
    if (src_ == nullptr) return fail(Status::NotOpen, "no file open");
    if (bx >= info_.blocksX || by >= info_.blocksY || band >= info_.bands)
        return fail(Status::OutOfRange, "block (%u, %u), band %u is out of range", bx, by, band);
    if (buffer == nullptr || bufferSize < info_.blockBytes)
        return fail(Status::BufferTooSmall, "buffer of %llu bytes, block needs %llu",
                    static_cast<unsigned long long>(buffer ? bufferSize : 0),
                    static_cast<unsigned long long>(info_.blockBytes));
    unsigned char* out = static_cast<unsigned char*>(buffer);
    const std::uint64_t tile = tileIndex(bx, by);
    if (offsets_[tile] == 0 || counts_[tile] == 0) {
        fillNoData(out);
        return Status::Sparse;
    }

    // A tile is always stored full size, also at the right and bottom image edge.
    if (info_.bands == 1) return readTile(bx, by, out, info_.blockBytes);

    // 3 bands, pixel-interleaved: the stored tile holds all of them. It is read once
    // into the scratch buffer and kept, so the other two bands cost no file access.
    if (!(cacheValid_ && cacheTile_ == tile)) {
        cacheValid_ = false;
        const Status s = readTile(bx, by, scratch_, 3 * info_.blockBytes);
        if (s != Status::Ok) return s;
        cacheTile_ = tile;
        cacheValid_ = true;
    }
    const unsigned size = dataTypeSize(info_.dataType);
    const unsigned char* src = scratch_ + band * size;
    for (std::size_t i = 0; i < kTileSamples; ++i, src += 3 * size, out += size)
        std::memcpy(out, src, size);
    return Status::Ok;
}

// --- helpers -------------------------------------------------------------------------

Status Reader::fail(Status s, const char* format, ...) noexcept {
    va_list args;
    va_start(args, format);
    std::vsnprintf(message_, sizeof message_, format, args);
    va_end(args);
    return s;
}

// Tiles are numbered row by row; all bands of a pixel share one stored tile.
std::uint64_t Reader::tileIndex(std::uint32_t bx, std::uint32_t by) const noexcept {
    return static_cast<std::uint64_t>(by) * info_.blocksX + bx;
}

void Reader::release() noexcept {
    std::free(offsets_);
    std::free(counts_);
    std::free(scratch_);
    std::free(metadata_);
    std::free(geoKeys_);
    offsets_ = counts_ = nullptr;
    scratch_ = nullptr;
    metadata_ = nullptr;
    geoKeys_ = nullptr;
    geoKeyCount_ = 0;
    cacheValid_ = false;
    info_ = ImageInfo{};
    geo_ = GeoInfo{};
    file_.close();
    memory_ = MemorySource();
    src_ = nullptr;
    size_ = 0;
    big_ = false;
}

// --- tile data -----------------------------------------------------------------------

// The first `size` stored bytes of tile (bx, by). Data is uncompressed little-endian,
// which is the host's byte order: the bytes are the samples.
Status Reader::readTile(std::uint32_t bx, std::uint32_t by, unsigned char* dst, std::size_t size) noexcept {
    const std::uint64_t tile = tileIndex(bx, by), offset = offsets_[tile], stored = counts_[tile];
    if (stored < size)
        return fail(Status::Corrupt, "block (%u, %u) stores %llu bytes, %llu expected", bx, by,
                    static_cast<unsigned long long>(stored), static_cast<unsigned long long>(size));
    if (offset > size_ || size > size_ - offset)
        return fail(Status::Corrupt, "block (%u, %u) lies outside the file", bx, by);
    if (!src_->readAt(offset, dst, size)) return fail(Status::Io, "read of block (%u, %u) failed", bx, by);
    return Status::Ok;
}

// An absent tile reads as the nodata value converted to the sample type the way GDAL
// does it (rounded, saturated, NaN -> 0), or as 0 if the file has no nodata value.
void Reader::fillNoData(unsigned char* out) const noexcept {
    const double lo = info_.dataType == DataType::Int16 ? -32768.0 : 0.0;
    const double hi = info_.dataType == DataType::UInt8 ? 255.0
                    : info_.dataType == DataType::UInt16 ? 65535.0 : 32767.0;
    const double d = geo_.noData;
    long v = 0;
    if (geo_.hasNoData && d == d)
        v = static_cast<long>(d <= lo ? lo : d >= hi ? hi : d < 0 ? d - 0.5 : d + 0.5);
    if (info_.dataType == DataType::UInt8) {
        std::memset(out, static_cast<int>(v), kTileSamples);
        return;
    }
    const std::uint16_t sample = static_cast<std::uint16_t>(v);  // Int16: the same two bytes
    for (std::size_t i = 0; i < kTileSamples; ++i) std::memcpy(out + 2 * i, &sample, 2);
}

// --- TIFF structure ------------------------------------------------------------------

Status Reader::openSource(Source& source) noexcept {
    src_ = &source;
    const Status s = parse();
    if (s != Status::Ok) release();  // message_ stays
    return s;
}

// File header -> offset of the first image directory -> parseImage.
Status Reader::parse() noexcept {
    size_ = src_->size();
    unsigned char head[16];
    if (size_ < 8) return fail(Status::NotTiff, "not a TIFF file (only %llu bytes)",
                               static_cast<unsigned long long>(size_));
    if (!src_->readAt(0, head, 8)) return fail(Status::Io, "cannot read the file header");
    if (head[0] == 'M' && head[1] == 'M' && head[2] == 0 && (head[3] == 42 || head[3] == 43))
        return fail(Status::Unsupported, "big-endian files are not supported");
    if (head[0] != 'I' || head[1] != 'I')
        return fail(Status::NotTiff, "not a TIFF file (no II byte order mark)");
    const std::uint16_t magic = rd16(head + 2);
    std::uint64_t first = 0;
    if (magic == 42) {
        big_ = false;
        first = rd32(head + 4);
    } else if (magic == 43) {
        big_ = true;
        if (size_ < 16 || !src_->readAt(8, head + 8, 8))
            return fail(Status::Corrupt, "BigTIFF header is cut short");
        if (rd16(head + 4) != 8 || rd16(head + 6) != 0)
            return fail(Status::Corrupt, "BigTIFF header with an offset size other than 8");
        first = rd64(head + 8);
    } else {
        return fail(Status::NotTiff, "not a TIFF file (magic number %u)", magic);
    }
    if (first == 0) return fail(Status::Corrupt, "the file has no image directory");
    return parseImage(first);
}

// Read the entries of the image directory at `offset` into memory.
Status Reader::loadIfd(std::uint64_t offset, Ifd& ifd) noexcept {
    const unsigned countBytes = big_ ? 8 : 2, entryBytes = big_ ? 20 : 12;
    unsigned char b[8];
    if (offset > size_ || size_ - offset < countBytes)
        return fail(Status::Corrupt, "image directory at %llu lies outside the file",
                    static_cast<unsigned long long>(offset));
    if (!src_->readAt(offset, b, countBytes)) return fail(Status::Io, "cannot read the image directory");
    ifd.count = big_ ? rd64(b) : rd16(b);
    const std::uint64_t entries = offset + countBytes;
    if (ifd.count == 0 || ifd.count > (size_ - entries) / entryBytes)
        return fail(Status::Corrupt, "image directory at %llu with %llu entries does not fit the file",
                    static_cast<unsigned long long>(offset), static_cast<unsigned long long>(ifd.count));
    const std::size_t bytes = static_cast<std::size_t>(ifd.count * entryBytes);
    ifd.raw = static_cast<unsigned char*>(std::malloc(bytes));
    if (ifd.raw == nullptr) return fail(Status::OutOfMemory, "no memory for the image directory");
    if (!src_->readAt(entries, ifd.raw, bytes)) return fail(Status::Io, "cannot read the image directory");
    return Status::Ok;
}

bool Reader::find(const Ifd& ifd, std::uint16_t tag, Entry& e) const noexcept {
    const unsigned entryBytes = big_ ? 20 : 12;
    for (std::uint64_t i = 0; i < ifd.count; ++i) {
        const unsigned char* p = ifd.raw + i * entryBytes;
        if (rd16(p) != tag) continue;
        e.tag = tag;
        e.type = rd16(p + 2);
        e.count = big_ ? rd64(p + 4) : rd32(p + 4);
        e.value = p + (big_ ? 12 : 8);
        return true;
    }
    return false;
}

// Size of an entry's data and where it starts; checks that it lies inside the file.
Status Reader::entryData(const Entry& e, std::uint64_t& bytes, bool& inlined,
                         std::uint64_t& offset) noexcept {
    const unsigned ts = typeSize(e.type);
    if (ts == 0) return fail(Status::Corrupt, "tag %u has the unknown field type %u", e.tag, e.type);
    if (mulOverflow(ts, e.count, bytes))
        return fail(Status::Corrupt, "tag %u: value count overflows", e.tag);
    inlined = bytes <= (big_ ? 8u : 4u);
    offset = 0;
    if (!inlined) {
        offset = big_ ? rd64(e.value) : rd32(e.value);
        if (offset > size_ || bytes > size_ - offset)
            return fail(Status::Corrupt, "tag %u: data lies outside the file", e.tag);
    }
    return Status::Ok;
}

// Copy `size` raw bytes of an entry's data, starting `start` bytes in.
Status Reader::entryBytes(const Entry& e, std::uint64_t start, void* dst, std::size_t size) noexcept {
    std::uint64_t bytes = 0, offset = 0;
    bool inlined = false;
    const Status s = entryData(e, bytes, inlined, offset);
    if (s != Status::Ok) return s;
    if (start > bytes || size > bytes - start)
        return fail(Status::Corrupt, "tag %u holds fewer values than needed", e.tag);
    if (inlined) {
        if (size != 0) std::memcpy(dst, e.value + start, size);
    } else if (!src_->readAt(offset + start, dst, size)) {
        return fail(Status::Io, "cannot read the data of tag %u", e.tag);
    }
    return Status::Ok;
}

// `n` unsigned integers (BYTE / SHORT / LONG / LONG8 / IFD / IFD8) from index `start`.
Status Reader::readUInts(const Entry& e, std::uint64_t start, std::uint64_t n, std::uint64_t* out) noexcept {
    const unsigned ts = typeSize(e.type);
    const bool integer = e.type == 1 || e.type == 3 || e.type == 4 || e.type == 13 ||
                         e.type == 16 || e.type == 18;
    if (!integer) return fail(Status::Corrupt, "tag %u: field type %u is not an unsigned integer", e.tag, e.type);
    if (start > e.count || n > e.count - start)
        return fail(Status::Corrupt, "tag %u holds %llu values, %llu needed", e.tag,
                    static_cast<unsigned long long>(e.count),
                    static_cast<unsigned long long>(start + n));
    unsigned char chunk[4096];
    const std::uint64_t perChunk = sizeof chunk / ts;
    for (std::uint64_t done = 0; done < n;) {
        const std::uint64_t m = n - done < perChunk ? n - done : perChunk;
        const Status s = entryBytes(e, (start + done) * ts, chunk, static_cast<std::size_t>(m * ts));
        if (s != Status::Ok) return s;
        for (std::uint64_t i = 0; i < m; ++i) {
            const unsigned char* p = chunk + i * ts;
            out[done + i] = ts == 1 ? p[0] : ts == 2 ? rd16(p) : ts == 4 ? rd32(p) : rd64(p);
        }
        done += m;
    }
    return Status::Ok;
}

Status Reader::readDoubles(const Entry& e, std::uint64_t n, double* out) noexcept {
    if (e.type != 12) return fail(Status::Corrupt, "tag %u: field type %u is not DOUBLE", e.tag, e.type);
    if (e.count < n) return fail(Status::Corrupt, "tag %u holds fewer values than needed", e.tag);
    return entryBytes(e, 0, out, static_cast<std::size_t>(n) * sizeof(double));
}

// First value of a tag, or `fallback` if the tag is absent.
Status Reader::scalar(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t& v,
                      bool* found) noexcept {
    Entry e;
    const bool have = find(ifd, tag, e);
    if (found != nullptr) *found = have;
    v = fallback;
    return have ? readUInts(e, 0, 1, &v) : Status::Ok;
}

// A per-sample tag (BitsPerSample, SampleFormat): first value, `uniform` = all equal.
Status Reader::perSample(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t samples,
                         std::uint64_t& v, bool& uniform) noexcept {
    Entry e;
    uniform = true;
    v = fallback;
    if (!find(ifd, tag, e)) return Status::Ok;
    const std::uint64_t n = e.count < samples ? e.count : samples;
    if (n == 0) return fail(Status::Corrupt, "tag %u is empty", tag);
    for (std::uint64_t i = 0; i < n; ++i) {
        std::uint64_t x = 0;
        const Status s = readUInts(e, i, 1, &x);
        if (s != Status::Ok) return s;
        if (i == 0) v = x;
        else if (x != v) uniform = false;
    }
    return Status::Ok;
}

// The image directory at `ifdOffset`: layout tags -> info_, project constraints, tile
// tables, then the georeferencing (parseGeo).
Status Reader::parseImage(std::uint64_t ifdOffset) noexcept {
    Ifd ifd;
    Status s = loadIfd(ifdOffset, ifd);
    if (s != Status::Ok) return s;

    std::uint64_t width = 0, height = 0, bands = 1, bits = 1, format = 1, compression = 1,
                  predictor = 1, photometric = 0, planar = 1, tileWidth = 0, tileHeight = 0;
    bool haveWidth = false, haveHeight = false, tiled = false, haveTileHeight = false,
         uniformBits = true, uniformFormat = true;
    if ((s = scalar(ifd, kImageWidth, 0, width, &haveWidth)) != Status::Ok) return s;
    if ((s = scalar(ifd, kImageLength, 0, height, &haveHeight)) != Status::Ok) return s;
    if ((s = scalar(ifd, kSamplesPerPixel, 1, bands)) != Status::Ok) return s;
    if ((s = perSample(ifd, kBitsPerSample, 1, bands, bits, uniformBits)) != Status::Ok) return s;
    if ((s = perSample(ifd, kSampleFormat, 1, bands, format, uniformFormat)) != Status::Ok) return s;
    if ((s = scalar(ifd, kCompression, 1, compression)) != Status::Ok) return s;
    if ((s = scalar(ifd, kPredictor, 1, predictor)) != Status::Ok) return s;
    if ((s = scalar(ifd, kPhotometric, 0, photometric)) != Status::Ok) return s;
    if ((s = scalar(ifd, kPlanarConfig, 1, planar)) != Status::Ok) return s;
    if ((s = scalar(ifd, kTileWidth, 0, tileWidth, &tiled)) != Status::Ok) return s;
    if ((s = scalar(ifd, kTileLength, 0, tileHeight, &haveTileHeight)) != Status::Ok) return s;

    // A broken file.
    const std::uint64_t max32 = 0xFFFFFFFFull;
    if (!haveWidth || !haveHeight || width == 0 || height == 0 || width > max32 || height > max32)
        return fail(Status::Corrupt, "missing or invalid image size");
    if (bands == 0 || bands > 0xFFFFu) return fail(Status::Corrupt, "invalid SamplesPerPixel");
    if (planar != 1 && planar != 2)
        return fail(Status::Corrupt, "invalid PlanarConfiguration %llu", static_cast<unsigned long long>(planar));
    if (tiled && (!haveTileHeight || tileWidth == 0 || tileHeight == 0 || tileWidth > max32 ||
                  tileHeight > max32))
        return fail(Status::Corrupt, "invalid tile size");

    // SampleFormat 1 = unsigned, 4 = "undefined" which GDAL reads as unsigned, 2 = signed.
    DataType type = DataType::Unknown;
    if (uniformBits && uniformFormat) {
        if ((format == 1 || format == 4) && bits == 8) type = DataType::UInt8;
        else if ((format == 1 || format == 4) && bits == 16) type = DataType::UInt16;
        else if (format == 2 && bits == 16) type = DataType::Int16;
    }

    // A valid file outside the project constraints. The first reason that applies is
    // reported. (PlanarConfiguration has no meaning for one band; GDAL writes 2 for
    // INTERLEAVE=BAND.)
    if (compression != 1)
        return fail(Status::Unsupported, "compression %llu (%s) is not supported",
                    static_cast<unsigned long long>(compression), compressionName(compression));
    if (predictor != 1)
        return fail(Status::Unsupported, "predictor %llu is not supported",
                    static_cast<unsigned long long>(predictor));
    if (type == DataType::Unknown)
        return fail(Status::Unsupported,
                    "%llu-bit samples of format %llu are not supported (Byte, UInt16, Int16 only)",
                    static_cast<unsigned long long>(bits), static_cast<unsigned long long>(format));
    if (photometric == 6) return fail(Status::Unsupported, "YCbCr data is not supported");
    if (!tiled) return fail(Status::Unsupported, "strips are not supported (tiles only)");
    if (tileWidth != kTileSize || tileHeight != kTileSize)
        return fail(Status::Unsupported, "%llux%llu tiles are not supported (%ux%u only)",
                    static_cast<unsigned long long>(tileWidth), static_cast<unsigned long long>(tileHeight),
                    static_cast<unsigned>(kTileSize), static_cast<unsigned>(kTileSize));
    if (bands != 1 && bands != 3)
        return fail(Status::Unsupported, "%llu bands are not supported (1 or 3 only)",
                    static_cast<unsigned long long>(bands));
    if (planar == 2 && bands != 1)
        return fail(Status::Unsupported, "band-interleaved data is not supported");

    info_.width = static_cast<std::uint32_t>(width);
    info_.height = static_cast<std::uint32_t>(height);
    info_.blocksX = (info_.width - 1) / kTileSize + 1;
    info_.blocksY = (info_.height - 1) / kTileSize + 1;
    info_.bands = static_cast<std::uint16_t>(bands);
    info_.dataType = type;
    info_.blockBytes = kTileSamples * dataTypeSize(type);

    // Tile tables. Check they lie inside the file before sizing memory by their count.
    const std::uint64_t tiles = static_cast<std::uint64_t>(info_.blocksX) * info_.blocksY;
    Entry offsets, counts;
    if (!find(ifd, kTileOffsets, offsets) || !find(ifd, kTileByteCounts, counts))
        return fail(Status::Corrupt, "tile offsets or byte counts are missing");
    std::uint64_t bytes = 0, at = 0;
    bool inlined = false;
    if ((s = entryData(offsets, bytes, inlined, at)) != Status::Ok) return s;
    if ((s = entryData(counts, bytes, inlined, at)) != Status::Ok) return s;
    if (offsets.count < tiles || counts.count < tiles)
        return fail(Status::Corrupt, "%llu tiles, but the offset tables hold fewer",
                    static_cast<unsigned long long>(tiles));
    const std::size_t tableBytes = static_cast<std::size_t>(tiles) * sizeof(std::uint64_t);
    offsets_ = static_cast<std::uint64_t*>(std::malloc(tableBytes));
    counts_ = static_cast<std::uint64_t*>(std::malloc(tableBytes));
    if (info_.bands == 3) scratch_ = static_cast<unsigned char*>(std::malloc(3 * info_.blockBytes));
    if (offsets_ == nullptr || counts_ == nullptr || (info_.bands == 3 && scratch_ == nullptr))
        return fail(Status::OutOfMemory, "no memory for the tile tables");
    if ((s = readUInts(offsets, 0, tiles, offsets_)) != Status::Ok) return s;
    if ((s = readUInts(counts, 0, tiles, counts_)) != Status::Ok) return s;

    return parseGeo(ifd);
}

// Nodata value, GDAL metadata, GeoKeys (CRS) and the geotransform -> geo_.
Status Reader::parseGeo(const Ifd& ifd) noexcept {
    Entry e;
    Status s;
    if (find(ifd, kGdalNoData, e)) {
        if (e.type != 2) return fail(Status::Corrupt, "GDAL_NODATA is not ASCII");
        char text[64];
        const std::size_t n = e.count < sizeof text - 1 ? static_cast<std::size_t>(e.count) : sizeof text - 1;
        if ((s = entryBytes(e, 0, text, n)) != Status::Ok) return s;
        text[n] = '\0';
        geo_.hasNoData = parseDouble(text, geo_.noData);
    }
    if (find(ifd, kGdalMetadata, e)) {
        if (e.type != 2) return fail(Status::Corrupt, "GDAL_METADATA is not ASCII");
        const std::size_t n = static_cast<std::size_t>(e.count);  // ASCII: bytes = count, <= file size
        std::uint64_t bytes = 0, at = 0;
        bool inlined = false;
        if ((s = entryData(e, bytes, inlined, at)) != Status::Ok) return s;
        metadata_ = static_cast<char*>(std::malloc(n + 1));
        if (metadata_ == nullptr) return fail(Status::OutOfMemory, "no memory for GDAL_METADATA");
        if ((s = entryBytes(e, 0, metadata_, n)) != Status::Ok) return s;
        metadata_[n] = '\0';
    }
    if (find(ifd, kGeoKeyDirectory, e)) {
        if (e.type != 3) return fail(Status::Corrupt, "GeoKeyDirectory is not of type SHORT");
        std::uint64_t bytes = 0, at = 0;
        bool inlined = false;
        if ((s = entryData(e, bytes, inlined, at)) != Status::Ok) return s;
        const std::size_t n = static_cast<std::size_t>(e.count);  // SHORTs, in the file: <= size / 2
        geoKeys_ = static_cast<std::uint16_t*>(std::malloc((n + 1) * sizeof(std::uint16_t)));
        if (geoKeys_ == nullptr) return fail(Status::OutOfMemory, "no memory for the GeoKeyDirectory");
        if ((s = entryBytes(e, 0, geoKeys_, n * sizeof(std::uint16_t))) != Status::Ok) return s;
        geoKeyCount_ = n;
    }
    std::uint16_t key = 0, model = 0, projected = 0, geographic = 0;
    if (geoKey(1024, key)) model = key;                 // GTModelTypeGeoKey
    geo_.modelType = model;
    geo_.pixelIsPoint = geoKey(1025, key) && key == 2;  // GTRasterTypeGeoKey
    const bool haveProjected = geoKey(3072, projected) && projected != 0 && projected != 32767;
    const bool haveGeographic = geoKey(2048, geographic) && geographic != 0 && geographic != 32767;
    if (model == 1) geo_.epsg = haveProjected ? projected : 0u;
    else if (model == 2) geo_.epsg = haveGeographic ? geographic : 0u;
    else if (model == 0) geo_.epsg = haveProjected ? projected : haveGeographic ? geographic : 0u;

    // Geotransform as GDAL derives it: pixel scale + one tiepoint, else the matrix.
    Entry scale, tie, matrix;
    double* gt = geo_.geoTransform;
    if (find(ifd, kModelPixelScale, scale) && scale.count >= 2 && find(ifd, kModelTiepoint, tie) &&
        tie.count >= 6) {
        double sc[2], tp[6];
        if ((s = readDoubles(scale, 2, sc)) != Status::Ok) return s;
        if ((s = readDoubles(tie, 6, tp)) != Status::Ok) return s;
        gt[1] = sc[0];
        gt[2] = 0;
        gt[4] = 0;
        gt[5] = sc[1] < 0 ? sc[1] : -sc[1];
        gt[0] = tp[3] - tp[0] * gt[1];
        gt[3] = tp[4] - tp[1] * gt[5];
        geo_.hasGeoTransform = true;
    } else if (find(ifd, kModelTransformation, matrix) && matrix.count == 16) {
        double m[16];
        if ((s = readDoubles(matrix, 16, m)) != Status::Ok) return s;
        gt[0] = m[3];
        gt[1] = m[0];
        gt[2] = m[1];
        gt[3] = m[7];
        gt[4] = m[4];
        gt[5] = m[5];
        geo_.hasGeoTransform = true;
    }
    if (geo_.hasGeoTransform && geo_.pixelIsPoint) {
        gt[0] -= gt[1] * 0.5 + gt[2] * 0.5;
        gt[3] -= gt[4] * 0.5 + gt[5] * 0.5;
    }
    return Status::Ok;
}

}  // namespace geotiff
