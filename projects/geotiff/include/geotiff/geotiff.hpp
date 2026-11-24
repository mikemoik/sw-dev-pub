// geotiff.hpp — dependency-free GeoTIFF block reader, C++17, single header.
//
// Reads GeoTIFF files as GDAL writes them, block by block (the equivalent of GDAL's
// ReadBlock): classic TIFF and BigTIFF, both byte orders, tiles and strips, pixel- and
// band-interleaved, 8/16/32/64-bit integer and 32/64-bit float samples, overviews, and
// GDAL sparse files (SPARSE_OK=TRUE: absent blocks read back as nodata or 0).
// Uncompressed data only; compressed files are rejected at open().
//
// No exceptions, no RTTI: every fallible call returns a geotiff::Status, the text for
// the last failure is in Reader::message(). Standard library only.
//
// A Reader is not thread-safe; use one Reader per thread.
//
// SPDX-License-Identifier: MIT
#ifndef GEOTIFF_GEOTIFF_HPP
#define GEOTIFF_GEOTIFF_HPP

#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>

#define GEOTIFF_VERSION_MAJOR 0
#define GEOTIFF_VERSION_MINOR 1
#define GEOTIFF_VERSION_PATCH 0

namespace geotiff {

// ---------------------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------------------

enum class Status : std::uint8_t {
    Ok = 0,
    Sparse,         // readBlock: the block is absent in the file; buffer holds nodata / 0
    Io,             // the file cannot be opened or read
    NotTiff,        // no TIFF / BigTIFF header
    Corrupt,        // inconsistent or out-of-file structure
    Unsupported,    // valid TIFF outside the supported subset (compression, bit depth, ...)
    OutOfRange,     // image, block or band index out of range
    BufferTooSmall, // caller buffer smaller than ImageInfo::blockBytes
    OutOfMemory,
    NotOpen,
};

// True for the two non-failure results of readBlock.
constexpr bool ok(Status s) noexcept { return s == Status::Ok || s == Status::Sparse; }

inline const char* statusName(Status s) noexcept {
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

// ---------------------------------------------------------------------------------------
// I/O: read-at interface, stdio-backed and in-memory implementations
// ---------------------------------------------------------------------------------------

class Source {
public:
    virtual ~Source() = default;
    // Total size in bytes; must not change while a Reader uses the source.
    virtual std::uint64_t size() const noexcept = 0;
    // Copies exactly `size` bytes starting at `offset` to `dst`; false on any failure.
    virtual bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept = 0;
};

class MemorySource final : public Source {
public:
    MemorySource() noexcept = default;
    MemorySource(const void* data, std::size_t size) noexcept
        : data_(static_cast<const unsigned char*>(data)), size_(size) {}
    std::uint64_t size() const noexcept override { return size_; }
    bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept override {
        if (offset > size_ || size > size_ - offset) return false;
        if (size != 0) std::memcpy(dst, data_ + offset, size);
        return true;
    }

private:
    const unsigned char* data_ = nullptr;
    std::size_t size_ = 0;
};

class FileSource final : public Source {
public:
    FileSource() noexcept = default;
    ~FileSource() override { close(); }
    FileSource(const FileSource&) = delete;
    FileSource& operator=(const FileSource&) = delete;

    bool open(const char* path) noexcept {
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
    void close() noexcept {
        if (file_ != nullptr) std::fclose(file_);
        file_ = nullptr;
        size_ = 0;
    }
    std::uint64_t size() const noexcept override { return size_; }
    bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept override {
        if (file_ == nullptr || offset > size_ || size > size_ - offset) return false;
        if (size == 0) return true;
        if (!seek(offset, SEEK_SET)) return false;
        return std::fread(dst, 1, size, file_) == size;
    }

private:
    // 64-bit file positions: the platform call where there is one, plain fseek otherwise.
    bool seek(std::uint64_t offset, int whence) noexcept {
#if defined(_WIN32)
        return _fseeki64(file_, static_cast<long long>(offset), whence) == 0;
#elif defined(__unix__) || defined(__APPLE__)
        return fseeko(file_, static_cast<off_t>(offset), whence) == 0;
#else
        if (offset > static_cast<std::uint64_t>(std::numeric_limits<long>::max())) return false;
        return std::fseek(file_, static_cast<long>(offset), whence) == 0;
#endif
    }
    std::int64_t tell() noexcept {
#if defined(_WIN32)
        return static_cast<std::int64_t>(_ftelli64(file_));
#elif defined(__unix__) || defined(__APPLE__)
        return static_cast<std::int64_t>(ftello(file_));
#else
        return static_cast<std::int64_t>(std::ftell(file_));
#endif
    }

    std::FILE* file_ = nullptr;
    std::uint64_t size_ = 0;
};

// ---------------------------------------------------------------------------------------
// Image description
// ---------------------------------------------------------------------------------------

enum class DataType : std::uint8_t {
    Unknown = 0, UInt8, Int8, UInt16, Int16, UInt32, Int32, UInt64, Int64, Float32, Float64
};

inline unsigned dataTypeSize(DataType t) noexcept {
    switch (t) {
        case DataType::UInt8: case DataType::Int8: return 1;
        case DataType::UInt16: case DataType::Int16: return 2;
        case DataType::UInt32: case DataType::Int32: case DataType::Float32: return 4;
        case DataType::UInt64: case DataType::Int64: case DataType::Float64: return 8;
        case DataType::Unknown: break;
    }
    return 0;
}

// GDAL's names (Byte, Int8, UInt16, ...).
inline const char* dataTypeName(DataType t) noexcept {
    switch (t) {
        case DataType::UInt8: return "Byte";
        case DataType::Int8: return "Int8";
        case DataType::UInt16: return "UInt16";
        case DataType::Int16: return "Int16";
        case DataType::UInt32: return "UInt32";
        case DataType::Int32: return "Int32";
        case DataType::UInt64: return "UInt64";
        case DataType::Int64: return "Int64";
        case DataType::Float32: return "Float32";
        case DataType::Float64: return "Float64";
        case DataType::Unknown: break;
    }
    return "Unknown";
}

// One image file directory (IFD): image 0 is the main image, the others are overviews
// (`overview`), masks (`mask`) or further pages.
struct ImageInfo {
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t blockWidth;   // tile width, or the image width for strips
    std::uint32_t blockHeight;  // tile height, or rows per strip
    std::uint32_t blocksX;
    std::uint32_t blocksY;
    std::uint16_t bands;
    std::uint16_t bitsPerSample;
    DataType dataType;
    bool tiled;
    bool planarSeparate;        // one block per band in the file (INTERLEAVE=BAND)
    bool overview;              // reduced-resolution image
    bool mask;                  // transparency mask (listed, not interpreted)
    std::uint16_t compression;  // TIFF Compression tag
    std::uint16_t predictor;    // TIFF Predictor tag
    std::uint16_t photometric;
    std::uint64_t blockBytes;   // size of one band block = buffer size for readBlock
    Status status;              // Ok, or Unsupported: listed, but its blocks cannot be read
};

// Georeferencing of the main image, as GDAL reports it.
struct GeoInfo {
    bool hasGeoTransform;
    // x = gt[0] + col*gt[1] + row*gt[2];  y = gt[3] + col*gt[4] + row*gt[5]
    // (col, row) = pixel corner; for PixelIsPoint files shifted by half a pixel like GDAL.
    double geoTransform[6];
    bool pixelIsPoint;          // GTRasterTypeGeoKey = RasterPixelIsPoint
    std::uint16_t modelType;    // GTModelTypeGeoKey: 0 none, 1 projected, 2 geographic, 3 geocentric
    std::uint32_t epsg;         // EPSG code of the CRS, 0 = none / user-defined
    bool hasNoData;
    double noData;
};

// ---------------------------------------------------------------------------------------
// Reader
// ---------------------------------------------------------------------------------------

class Reader {
public:
    Reader() noexcept { message_[0] = '\0'; }
    ~Reader() { close(); }
    Reader(const Reader&) = delete;
    Reader& operator=(const Reader&) = delete;

    // Open a file by path.
    Status open(const char* path) noexcept {
        close();
        if (!file_.open(path)) return fail(Status::Io, "cannot open '%s'", path ? path : "(null)");
        return openSource(file_);
    }
    // Open a file image held in memory; the bytes must outlive the Reader's use of them.
    Status open(const void* data, std::size_t size) noexcept {
        close();
        memory_ = MemorySource(data, size);
        return openSource(memory_);
    }
    // Open on a caller-owned source (mmap, custom file system, ...).
    Status open(Source& source) noexcept {
        close();
        return openSource(source);
    }

    void close() noexcept {
        release();
        message_[0] = '\0';
    }

    bool isOpen() const noexcept { return src_ != nullptr; }
    // Text for the last failed call ("" if none).
    const char* message() const noexcept { return message_; }

    bool bigTiff() const noexcept { return big_; }
    bool littleEndian() const noexcept { return le_; }

    // Number of IFDs; image 0 is the main image.
    std::size_t imageCount() const noexcept { return imageCount_; }
    const ImageInfo& image(std::size_t index = 0) const noexcept {
        static const ImageInfo none{};
        return index < imageCount_ ? images_[index].info : none;
    }
    // Why image `index` has status Unsupported ("" otherwise).
    const char* imageMessage(std::size_t index) const noexcept {
        return index < imageCount_ ? images_[index].reason : "";
    }

    // Overviews of the main image, largest first as stored: overviewImage(k) is the
    // image index to pass to readBlock.
    std::size_t overviewCount() const noexcept {
        std::size_t n = 0;
        for (std::size_t i = 1; i < imageCount_; ++i) n += isOverview(i) ? 1u : 0u;
        return n;
    }
    std::size_t overviewImage(std::size_t k) const noexcept {
        for (std::size_t i = 1; i < imageCount_; ++i)
            if (isOverview(i) && k-- == 0) return i;
        return imageCount_;
    }

    const GeoInfo& geo() const noexcept { return geo_; }
    // Raw GDAL_NODATA text ("" if the tag is absent).
    const char* noDataText() const noexcept { return noDataText_; }
    // Raw GDAL_METADATA XML ("" if the tag is absent).
    const char* gdalMetadata() const noexcept { return metadata_ ? metadata_ : ""; }
    // A GeoKey stored as a SHORT in the GeoKey directory (e.g. 3072 ProjectedCSType).
    bool geoKey(std::uint16_t id, std::uint16_t& value) const noexcept {
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

    // False for an absent (sparse) block and for any index out of range.
    bool blockPresent(std::size_t image, std::uint32_t bx, std::uint32_t by,
                      unsigned band = 0) const noexcept {
        std::uint64_t offset = 0, bytes = 0;
        return lookup(image, bx, by, band, offset, bytes) == Status::Ok && offset != 0 &&
               bytes != 0;
    }

    // File offset and stored byte count of a block (0 / 0 = absent).
    Status blockLocation(std::size_t image, std::uint32_t bx, std::uint32_t by, unsigned band,
                         std::uint64_t& offset, std::uint64_t& byteCount) noexcept {
        const Status s = lookup(image, bx, by, band, offset, byteCount);
        return s == Status::Ok ? s : failLookup(s, image, bx, by, band);
    }

    // Decode block (bx, by) of `band` (0-based) of image `image` into `buffer`
    // (>= ImageInfo::blockBytes): blockWidth x blockHeight samples of that band, row by
    // row, in host byte order — the same bytes GDAL's ReadBlock gives.
    //   Status::Ok      block read from the file
    //   Status::Sparse  block absent: buffer filled with the nodata value, or 0
    //   anything else   failure, buffer contents unspecified
    Status readBlock(std::size_t image, std::uint32_t bx, std::uint32_t by, unsigned band,
                     void* buffer, std::size_t bufferSize) noexcept {
        std::uint64_t offset = 0, stored = 0;
        const Status s = lookup(image, bx, by, band, offset, stored);
        if (s != Status::Ok) return failLookup(s, image, bx, by, band);
        const ImageInfo& in = images_[image].info;
        if (buffer == nullptr || bufferSize < in.blockBytes)
            return fail(Status::BufferTooSmall, "buffer of %llu bytes, block needs %llu",
                        static_cast<unsigned long long>(buffer ? bufferSize : 0),
                        static_cast<unsigned long long>(in.blockBytes));
        unsigned char* out = static_cast<unsigned char*>(buffer);
        const std::size_t blockBytes = static_cast<std::size_t>(in.blockBytes);

        if (offset == 0 || stored == 0) {
            fillNoData(in.dataType, out, blockBytes);
            return Status::Sparse;
        }

        // Rows stored for this block: the last strip is short, tiles are always full.
        std::uint64_t rows = in.blockHeight;
        if (!in.tiled) {
            const std::uint64_t left =
                in.height - static_cast<std::uint64_t>(by) * in.blockHeight;
            if (left < rows) rows = left;
        }
        const unsigned sampleBytes = dataTypeSize(in.dataType);
        const unsigned samplesPerPixel = in.planarSeparate ? 1u : in.bands;
        const std::size_t bandBytes =
            static_cast<std::size_t>(static_cast<std::uint64_t>(in.blockWidth) * rows * sampleBytes);
        std::uint64_t chunkBytes = 0;
        if (mulOverflow(bandBytes, samplesPerPixel, chunkBytes) ||
            chunkBytes > std::numeric_limits<std::size_t>::max())
            return fail(Status::Corrupt, "block (%u, %u) is too large", bx, by);
        const std::size_t need = static_cast<std::size_t>(chunkBytes);

        const bool swap = sampleBytes > 1 && le_ != hostLittleEndian();
        if (samplesPerPixel == 1) {
            const Status d = decodeChunk(in, bx, by, offset, stored, out, need);
            if (d != Status::Ok) return d;
            if (swap) swapSamples(out, bandBytes, sampleBytes);
        } else {
            const std::uint64_t chunkIndex =
                static_cast<std::uint64_t>(by) * in.blocksX + bx;
            if (!(cacheValid_ && cacheImage_ == image && cacheChunk_ == chunkIndex)) {
                cacheValid_ = false;
                // An uncompressed block cannot be larger than the file: checked before
                // the scratch buffer grows, so a corrupt size cannot drive the allocation.
                if (chunkBytes > size_)
                    return fail(Status::Corrupt, "block (%u, %u) lies outside the file", bx, by);
                if (need > scratchSize_) {
                    void* p = std::realloc(scratch_, need);
                    if (p == nullptr)
                        return fail(Status::OutOfMemory, "no memory for a %llu byte block",
                                    static_cast<unsigned long long>(chunkBytes));
                    scratch_ = static_cast<unsigned char*>(p);
                    scratchSize_ = need;
                }
                const Status d = decodeChunk(in, bx, by, offset, stored, scratch_, need);
                if (d != Status::Ok) return d;
                cacheImage_ = image;
                cacheChunk_ = chunkIndex;
                cacheValid_ = true;
            }
            deinterleave(scratch_ + static_cast<std::size_t>(band) * sampleBytes, out,
                         bandBytes / sampleBytes, sampleBytes,
                         static_cast<std::size_t>(samplesPerPixel) * sampleBytes, swap);
        }
        if (bandBytes < blockBytes) std::memset(out + bandBytes, 0, blockBytes - bandBytes);
        return Status::Ok;
    }

private:
    struct Image {
        ImageInfo info;
        std::uint64_t* offsets;   // blockCount entries
        std::uint64_t* counts;    // blockCount entries
        std::uint64_t blockCount;
        bool split;               // one stored strip per plane, exposed row by row
        char reason[96];
    };
    struct Entry {
        std::uint16_t tag;
        std::uint16_t type;
        std::uint64_t count;
        const unsigned char* value;  // the 4 / 8 value-or-offset bytes of the entry
    };
    struct Ifd {
        unsigned char* raw = nullptr;
        std::uint64_t count = 0;
        ~Ifd() { std::free(raw); }
    };

    enum : std::uint16_t {
        kNewSubfileType = 254, kImageWidth = 256, kImageLength = 257, kBitsPerSample = 258,
        kCompression = 259, kPhotometric = 262, kStripOffsets = 273, kSamplesPerPixel = 277,
        kRowsPerStrip = 278, kStripByteCounts = 279, kPlanarConfig = 284, kPredictor = 317,
        kTileWidth = 322, kTileLength = 323, kTileOffsets = 324, kTileByteCounts = 325,
        kSampleFormat = 339, kModelPixelScale = 33550, kModelTiepoint = 33922,
        kModelTransformation = 34264, kGeoKeyDirectory = 34735, kGdalMetadata = 42112,
        kGdalNoData = 42113
    };
    static constexpr std::size_t kMaxImages = 4096;

    // --- helpers -------------------------------------------------------------------------

#if defined(__GNUC__) || defined(__clang__)
    __attribute__((format(printf, 3, 4)))
#endif
    Status fail(Status s, const char* format, ...) noexcept {
        va_list args;
        va_start(args, format);
        std::vsnprintf(message_, sizeof message_, format, args);
        va_end(args);
        return s;
    }

    static bool hostLittleEndian() noexcept {
        const std::uint16_t one = 1;
        unsigned char first;
        std::memcpy(&first, &one, 1);
        return first == 1;
    }
    static bool mulOverflow(std::uint64_t a, std::uint64_t b, std::uint64_t& r) noexcept {
        if (a != 0 && b > std::numeric_limits<std::uint64_t>::max() / a) return true;
        r = a * b;
        return false;
    }
    std::uint16_t rd16(const unsigned char* p) const noexcept {
        return le_ ? static_cast<std::uint16_t>(p[0] | (p[1] << 8))
                   : static_cast<std::uint16_t>(p[1] | (p[0] << 8));
    }
    std::uint32_t rd32(const unsigned char* p) const noexcept {
        return le_ ? (static_cast<std::uint32_t>(p[0]) | static_cast<std::uint32_t>(p[1]) << 8 |
                      static_cast<std::uint32_t>(p[2]) << 16 | static_cast<std::uint32_t>(p[3]) << 24)
                   : (static_cast<std::uint32_t>(p[3]) | static_cast<std::uint32_t>(p[2]) << 8 |
                      static_cast<std::uint32_t>(p[1]) << 16 | static_cast<std::uint32_t>(p[0]) << 24);
    }
    std::uint64_t rd64(const unsigned char* p) const noexcept {
        return le_ ? (static_cast<std::uint64_t>(rd32(p + 4)) << 32 | rd32(p))
                   : (static_cast<std::uint64_t>(rd32(p)) << 32 | rd32(p + 4));
    }
    static void swapSamples(unsigned char* p, std::size_t bytes, unsigned size) noexcept {
        for (std::size_t i = 0; i + size <= bytes; i += size)
            for (unsigned a = 0, b = size - 1; a < b; ++a, --b) {
                const unsigned char t = p[i + a];
                p[i + a] = p[i + b];
                p[i + b] = t;
            }
    }
    static void deinterleave(const unsigned char* src, unsigned char* dst, std::size_t samples,
                             unsigned size, std::size_t stride, bool swap) noexcept {
        if (!swap) {
            for (std::size_t i = 0; i < samples; ++i, src += stride, dst += size)
                std::memcpy(dst, src, size);
        } else {
            for (std::size_t i = 0; i < samples; ++i, src += stride, dst += size)
                for (unsigned b = 0; b < size; ++b) dst[b] = src[size - 1 - b];
        }
    }

    bool isOverview(std::size_t i) const noexcept {
        return images_[i].info.overview && !images_[i].info.mask;
    }

    void release() noexcept {
        if (images_ != nullptr) {
            for (std::size_t i = 0; i < imageCount_; ++i) {
                std::free(images_[i].offsets);
                std::free(images_[i].counts);
            }
            std::free(images_);
        }
        images_ = nullptr;
        imageCount_ = 0;
        std::free(scratch_);
        scratch_ = nullptr;
        scratchSize_ = 0;
        cacheValid_ = false;
        std::free(metadata_);
        metadata_ = nullptr;
        std::free(geoKeys_);
        geoKeys_ = nullptr;
        geoKeyCount_ = 0;
        noDataText_[0] = '\0';
        geo_ = GeoInfo{};
        file_.close();
        memory_ = MemorySource();
        src_ = nullptr;
        size_ = 0;
        big_ = false;
        le_ = true;
    }

    // --- block lookup --------------------------------------------------------------------

    Status lookup(std::size_t image, std::uint32_t bx, std::uint32_t by, unsigned band,
                  std::uint64_t& offset, std::uint64_t& bytes) const noexcept {
        if (src_ == nullptr) return Status::NotOpen;
        if (image >= imageCount_) return Status::OutOfRange;
        const Image& im = images_[image];
        if (im.info.status != Status::Ok) return im.info.status;
        if (bx >= im.info.blocksX || by >= im.info.blocksY || band >= im.info.bands)
            return Status::OutOfRange;
        if (im.split) {
            const unsigned plane = im.info.planarSeparate ? band : 0u;
            const std::uint64_t base = im.offsets[plane], total = im.counts[plane];
            offset = bytes = 0;
            if (base == 0 || total == 0) return Status::Ok;  // the whole strip is absent
            const std::uint64_t rowBytes = static_cast<std::uint64_t>(im.info.width) *
                                           (im.info.planarSeparate ? 1u : im.info.bands);
            const std::uint64_t start = by * rowBytes;
            if (start >= total || base > std::numeric_limits<std::uint64_t>::max() - start)
                return Status::Corrupt;
            offset = base + start;
            bytes = total - start;
            return Status::Ok;
        }
        std::uint64_t index = static_cast<std::uint64_t>(by) * im.info.blocksX + bx;
        if (im.info.planarSeparate)
            index += static_cast<std::uint64_t>(band) * im.info.blocksX * im.info.blocksY;
        offset = im.offsets[index];
        bytes = im.counts[index];
        return Status::Ok;
    }
    Status failLookup(Status s, std::size_t image, std::uint32_t bx, std::uint32_t by,
                      unsigned band) noexcept {
        if (s == Status::NotOpen) return fail(s, "no file open");
        if (s == Status::Unsupported) return fail(s, "%s", images_[image].reason);
        if (s == Status::Corrupt) return fail(s, "block (%u, %u) lies beyond the stored strip", bx, by);
        return fail(s, "image %llu, block (%u, %u), band %u is out of range",
                    static_cast<unsigned long long>(image), bx, by, band);
    }

    // --- codec dispatch ------------------------------------------------------------------

    // Stored bytes of one block -> `size` decoded bytes in file byte order. The single
    // place that knows about Compression and Predictor: a codec is added as a case here
    // (and admitted in parseImage); the container layer and the API stay as they are.
    Status decodeChunk(const ImageInfo& in, std::uint32_t bx, std::uint32_t by, std::uint64_t offset,
                       std::uint64_t stored, unsigned char* dst, std::size_t size) noexcept {
        switch (in.compression) {
            case 1:  // none
                if (stored < size)
                    return fail(Status::Corrupt, "block (%u, %u) stores %llu bytes, %llu expected", bx, by,
                                static_cast<unsigned long long>(stored),
                                static_cast<unsigned long long>(size));
                if (offset > size_ || size > size_ - offset)
                    return fail(Status::Corrupt, "block (%u, %u) lies outside the file", bx, by);
                if (!src_->readAt(offset, dst, size))
                    return fail(Status::Io, "read of block (%u, %u) failed", bx, by);
                break;
            default:
                return fail(Status::Unsupported, "compression %u is not supported", in.compression);
        }
        switch (in.predictor) {
            case 1: break;  // none
            default: return fail(Status::Unsupported, "predictor %u is not supported", in.predictor);
        }
        return Status::Ok;
    }

    // --- nodata --------------------------------------------------------------------------

    static bool parseDouble(const char* text, double& value) noexcept {
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
    static bool isIntegerText(const char* t) noexcept {
        if (*t == '-' || *t == '+') ++t;
        if (*t < '0' || *t > '9') return false;
        while (*t >= '0' && *t <= '9') ++t;
        while (*t == ' ') ++t;
        return *t == '\0';
    }
    // Round to nearest and saturate, as GDAL converts a nodata value to the band type.
    template <typename T>
    static T toInteger(double d) noexcept {
        const double lo = static_cast<double>(std::numeric_limits<T>::min());
        const double hi = static_cast<double>(std::numeric_limits<T>::max());
        if (d != d) return 0;
        if (d <= lo) return std::numeric_limits<T>::min();
        if (d >= hi) return std::numeric_limits<T>::max();
        return static_cast<T>(d < 0 ? d - 0.5 : d + 0.5);
    }
    template <typename T>
    static unsigned put(T v, unsigned char* sample) noexcept {
        std::memcpy(sample, &v, sizeof v);
        return sizeof v;
    }
    void fillNoData(DataType type, unsigned char* out, std::size_t bytes) const noexcept {
        unsigned char sample[8] = {0, 0, 0, 0, 0, 0, 0, 0};
        unsigned size = dataTypeSize(type);
        if (geo_.hasNoData) {
            const double d = geo_.noData;
            const char* text = noDataText_;
            while (*text == ' ') ++text;
            switch (type) {
                case DataType::UInt8: put(toInteger<std::uint8_t>(d), sample); break;
                case DataType::Int8: put(toInteger<std::int8_t>(d), sample); break;
                case DataType::UInt16: put(toInteger<std::uint16_t>(d), sample); break;
                case DataType::Int16: put(toInteger<std::int16_t>(d), sample); break;
                case DataType::UInt32: put(toInteger<std::uint32_t>(d), sample); break;
                case DataType::Int32: put(toInteger<std::int32_t>(d), sample); break;
                case DataType::UInt64:
                    if (isIntegerText(text))  // exact beyond 2^53; strtoull saturates
                        put(static_cast<std::uint64_t>(
                                *text == '-' ? 0ull : std::strtoull(text, nullptr, 10)), sample);
                    else
                        put(toInteger<std::uint64_t>(d), sample);
                    break;
                case DataType::Int64:
                    if (isIntegerText(text))
                        put(static_cast<std::int64_t>(std::strtoll(text, nullptr, 10)), sample);
                    else
                        put(toInteger<std::int64_t>(d), sample);
                    break;
                case DataType::Float32: {
                    const double big = static_cast<double>(std::numeric_limits<float>::max());
                    float f;
                    if (d > big) f = std::numeric_limits<float>::infinity();
                    else if (d < -big) f = -std::numeric_limits<float>::infinity();
                    else f = static_cast<float>(d);
                    put(f, sample);
                    break;
                }
                case DataType::Float64: put(d, sample); break;
                case DataType::Unknown: break;
            }
        }
        bool zero = true;
        for (unsigned i = 0; i < size; ++i) zero = zero && sample[i] == 0;
        if (zero || size == 0) {
            std::memset(out, 0, bytes);
            return;
        }
        for (std::size_t i = 0; i + size <= bytes; i += size) std::memcpy(out + i, sample, size);
    }

    // --- TIFF structure ------------------------------------------------------------------

    static unsigned typeSize(std::uint16_t type) noexcept {
        switch (type) {
            case 1: case 2: case 6: case 7: return 1;       // BYTE ASCII SBYTE UNDEFINED
            case 3: case 8: return 2;                       // SHORT SSHORT
            case 4: case 9: case 11: case 13: return 4;     // LONG SLONG FLOAT IFD
            case 5: case 10: case 12: case 16: case 17: case 18: return 8;  // (S)RATIONAL DOUBLE LONG8 SLONG8 IFD8
            default: return 0;
        }
    }

    Status openSource(Source& source) noexcept {
        src_ = &source;
        const Status s = parse();
        if (s != Status::Ok) release();  // message_ stays
        return s;
    }

    Status parse() noexcept {
        size_ = src_->size();
        unsigned char head[16];
        if (size_ < 8) return fail(Status::NotTiff, "not a TIFF file (only %llu bytes)",
                                   static_cast<unsigned long long>(size_));
        if (!src_->readAt(0, head, 8)) return fail(Status::Io, "cannot read the file header");
        if (head[0] == 'I' && head[1] == 'I') le_ = true;
        else if (head[0] == 'M' && head[1] == 'M') le_ = false;
        else return fail(Status::NotTiff, "not a TIFF file (no II/MM byte order mark)");
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

        // Pass 1: walk the IFD chain to count the images.
        std::size_t n = 0;
        for (std::uint64_t offset = first; offset != 0; ++n) {
            if (n >= kMaxImages)
                return fail(Status::Corrupt, "more than %u image directories (chain loop?)",
                            static_cast<unsigned>(kMaxImages));
            std::uint64_t count = 0, entries = 0, next = 0;
            const Status s = ifdLayout(offset, count, entries, next);
            if (s != Status::Ok) return s;
            offset = next;
        }
        images_ = static_cast<Image*>(std::calloc(n, sizeof(Image)));
        if (images_ == nullptr) return fail(Status::OutOfMemory, "no memory for %u images",
                                            static_cast<unsigned>(n));
        imageCount_ = n;

        // Pass 2: parse each directory.
        std::uint64_t offset = first;
        for (std::size_t i = 0; i < n; ++i) {
            std::uint64_t next = 0;
            const Status s = parseImage(offset, i, next);
            if (s != Status::Ok) return s;
            offset = next;
        }
        if (images_[0].info.status != Status::Ok)
            return fail(images_[0].info.status, "%s", images_[0].reason);
        return Status::Ok;
    }

    // Entry count, position of the entries and the offset of the next IFD.
    Status ifdLayout(std::uint64_t offset, std::uint64_t& count, std::uint64_t& entries,
                     std::uint64_t& next) noexcept {
        const unsigned countBytes = big_ ? 8 : 2, entryBytes = big_ ? 20 : 12,
                       nextBytes = big_ ? 8 : 4;
        unsigned char b[8];
        if (offset > size_ || size_ - offset < countBytes)
            return fail(Status::Corrupt, "image directory at %llu lies outside the file",
                        static_cast<unsigned long long>(offset));
        if (!src_->readAt(offset, b, countBytes)) return fail(Status::Io, "cannot read an image directory");
        count = big_ ? rd64(b) : rd16(b);
        entries = offset + countBytes;
        const std::uint64_t room = size_ - entries;
        if (count == 0 || count > room / entryBytes || room - count * entryBytes < nextBytes)
            return fail(Status::Corrupt, "image directory at %llu with %llu entries does not fit the file",
                        static_cast<unsigned long long>(offset),
                        static_cast<unsigned long long>(count));
        if (!src_->readAt(entries + count * entryBytes, b, nextBytes))
            return fail(Status::Io, "cannot read an image directory");
        next = big_ ? rd64(b) : rd32(b);
        return Status::Ok;
    }

    bool find(const Ifd& ifd, std::uint16_t tag, Entry& e) const noexcept {
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
    Status entryData(const Entry& e, std::uint64_t& bytes, bool& inlined,
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
    Status entryBytes(const Entry& e, std::uint64_t start, void* dst, std::size_t size) noexcept {
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
    Status readUInts(const Entry& e, std::uint64_t start, std::uint64_t n, std::uint64_t* out) noexcept {
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
    Status readDoubles(const Entry& e, std::uint64_t n, double* out) noexcept {
        if (e.type != 12) return fail(Status::Corrupt, "tag %u: field type %u is not DOUBLE", e.tag, e.type);
        if (e.count < n) return fail(Status::Corrupt, "tag %u holds fewer values than needed", e.tag);
        for (std::uint64_t i = 0; i < n; ++i) {
            unsigned char b[8];
            const Status s = entryBytes(e, i * 8, b, 8);
            if (s != Status::Ok) return s;
            const std::uint64_t bits = rd64(b);
            std::memcpy(out + i, &bits, 8);
        }
        return Status::Ok;
    }
    // First value of a tag, or `fallback` if the tag is absent.
    Status scalar(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t& v,
                  bool* found = nullptr) noexcept {
        Entry e;
        const bool have = find(ifd, tag, e);
        if (found != nullptr) *found = have;
        v = fallback;
        return have ? readUInts(e, 0, 1, &v) : Status::Ok;
    }
    // A per-sample tag (BitsPerSample, SampleFormat): first value, `uniform` = all equal.
    Status perSample(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t samples,
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

    static const char* compressionName(std::uint64_t c) noexcept {
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

    Status parseImage(std::uint64_t ifdOffset, std::size_t index, std::uint64_t& next) noexcept {
        Image& im = images_[index];
        ImageInfo& in = im.info;
        Ifd ifd;
        std::uint64_t entries = 0;
        Status s = ifdLayout(ifdOffset, ifd.count, entries, next);
        if (s != Status::Ok) return s;
        const std::size_t rawBytes = static_cast<std::size_t>(ifd.count * (big_ ? 20u : 12u));
        ifd.raw = static_cast<unsigned char*>(std::malloc(rawBytes));
        if (ifd.raw == nullptr) return fail(Status::OutOfMemory, "no memory for an image directory");
        if (!src_->readAt(entries, ifd.raw, rawBytes)) return fail(Status::Io, "cannot read an image directory");

        std::uint64_t width = 0, height = 0, bands = 1, bits = 1, format = 1, compression = 1,
                      predictor = 1, photometric = 0, planar = 1, subfile = 0, tileWidth = 0,
                      tileHeight = 0, rowsPerStrip = 0xFFFFFFFFull;
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
        if ((s = scalar(ifd, kNewSubfileType, 0, subfile)) != Status::Ok) return s;
        if ((s = scalar(ifd, kTileWidth, 0, tileWidth, &tiled)) != Status::Ok) return s;
        if ((s = scalar(ifd, kTileLength, 0, tileHeight, &haveTileHeight)) != Status::Ok) return s;
        if ((s = scalar(ifd, kRowsPerStrip, 0xFFFFFFFFull, rowsPerStrip)) != Status::Ok) return s;

        const std::uint64_t max32 = 0xFFFFFFFFull;
        if (!haveWidth || !haveHeight || width == 0 || height == 0 || width > max32 || height > max32)
            return fail(Status::Corrupt, "image %u: missing or invalid image size",
                        static_cast<unsigned>(index));
        if (bands == 0 || bands > 0xFFFFu)
            return fail(Status::Corrupt, "image %u: invalid SamplesPerPixel", static_cast<unsigned>(index));
        if (planar != 1 && planar != 2)
            return fail(Status::Corrupt, "image %u: invalid PlanarConfiguration %llu",
                        static_cast<unsigned>(index), static_cast<unsigned long long>(planar));
        std::uint64_t blockWidth = width, blockHeight = rowsPerStrip < height ? rowsPerStrip : height;
        if (tiled) {
            blockWidth = tileWidth;
            blockHeight = tileHeight;
            if (!haveTileHeight || tileWidth == 0 || tileHeight == 0 || tileWidth > max32 || tileHeight > max32)
                return fail(Status::Corrupt, "image %u: invalid tile size", static_cast<unsigned>(index));
        } else if (blockHeight == 0) {
            return fail(Status::Corrupt, "image %u: RowsPerStrip is 0", static_cast<unsigned>(index));
        }

        in.width = static_cast<std::uint32_t>(width);
        in.height = static_cast<std::uint32_t>(height);
        in.blockWidth = static_cast<std::uint32_t>(blockWidth);
        in.blockHeight = static_cast<std::uint32_t>(blockHeight);
        in.blocksX = static_cast<std::uint32_t>((width + blockWidth - 1) / blockWidth);
        in.blocksY = static_cast<std::uint32_t>((height + blockHeight - 1) / blockHeight);
        in.bands = static_cast<std::uint16_t>(bands);
        in.bitsPerSample = static_cast<std::uint16_t>(bits > 0xFFFFu ? 0xFFFFu : bits);
        in.tiled = tiled;
        in.planarSeparate = planar == 2 && bands > 1;
        in.overview = (subfile & 1u) != 0;
        in.mask = (subfile & 4u) != 0;
        in.compression = static_cast<std::uint16_t>(compression > 0xFFFFu ? 0xFFFFu : compression);
        in.predictor = static_cast<std::uint16_t>(predictor > 0xFFFFu ? 0xFFFFu : predictor);
        in.photometric = static_cast<std::uint16_t>(photometric > 0xFFFFu ? 0xFFFFu : photometric);
        in.dataType = DataType::Unknown;
        in.status = Status::Ok;
        if (uniformBits && uniformFormat) {
            if (format == 1 || format == 4)  // unsigned, or "undefined" which GDAL reads as unsigned
                in.dataType = bits == 8 ? DataType::UInt8 : bits == 16 ? DataType::UInt16
                            : bits == 32 ? DataType::UInt32 : bits == 64 ? DataType::UInt64
                            : DataType::Unknown;
            else if (format == 2)
                in.dataType = bits == 8 ? DataType::Int8 : bits == 16 ? DataType::Int16
                            : bits == 32 ? DataType::Int32 : bits == 64 ? DataType::Int64
                            : DataType::Unknown;
            else if (format == 3)
                in.dataType = bits == 32 ? DataType::Float32 : bits == 64 ? DataType::Float64
                            : DataType::Unknown;
        }

        // Outside the supported subset: the image stays listed, its blocks are not readable.
        const std::uint64_t blockSamples = blockWidth * blockHeight;  // < 2^64
        std::uint64_t blockBytes = 0, blockCount = 0;
        const unsigned sampleBytes = dataTypeSize(in.dataType);
        const bool tooBig =
            sampleBytes != 0 &&
            (mulOverflow(blockSamples, sampleBytes, blockBytes) ||
             blockBytes > std::numeric_limits<std::size_t>::max() ||
             mulOverflow(static_cast<std::uint64_t>(in.blocksX) * in.blocksY,
                         in.planarSeparate ? bands : 1u, blockCount));
        const unsigned id = static_cast<unsigned>(index);
        if (compression != 1)
            std::snprintf(im.reason, sizeof im.reason, "image %u: compression %llu (%s) is not supported",
                          id, static_cast<unsigned long long>(compression), compressionName(compression));
        else if (predictor != 1)
            std::snprintf(im.reason, sizeof im.reason, "image %u: predictor %llu is not supported", id,
                          static_cast<unsigned long long>(predictor));
        else if (in.dataType == DataType::Unknown)
            std::snprintf(im.reason, sizeof im.reason,
                          "image %u: %llu-bit samples of format %llu are not supported", id,
                          static_cast<unsigned long long>(bits), static_cast<unsigned long long>(format));
        else if (photometric == 6)
            std::snprintf(im.reason, sizeof im.reason, "image %u: YCbCr data is not supported", id);
        else if (tooBig)
            std::snprintf(im.reason, sizeof im.reason, "image %u: block size too large", id);
        if (im.reason[0] != '\0') {
            in.blockBytes = tooBig ? 0 : blockBytes;
            in.status = Status::Unsupported;
        } else {
            in.blockBytes = blockBytes;
            Entry offsets, counts;
            if (!find(ifd, tiled ? kTileOffsets : kStripOffsets, offsets) ||
                !find(ifd, tiled ? kTileByteCounts : kStripByteCounts, counts))
                return fail(Status::Corrupt, "image %u: block offsets or byte counts are missing", id);
            // Check the tables lie inside the file before sizing memory by their count.
            std::uint64_t bytes = 0, at = 0;
            bool inlined = false;
            if ((s = entryData(offsets, bytes, inlined, at)) != Status::Ok) return s;
            if ((s = entryData(counts, bytes, inlined, at)) != Status::Ok) return s;
            if (offsets.count < blockCount || counts.count < blockCount)
                return fail(Status::Corrupt, "image %u: %llu blocks, but the offset tables hold fewer", id,
                            static_cast<unsigned long long>(blockCount));
            if (blockCount > std::numeric_limits<std::size_t>::max() / sizeof(std::uint64_t))
                return fail(Status::OutOfMemory, "image %u: too many blocks", id);
            const std::size_t tableBytes = static_cast<std::size_t>(blockCount) * sizeof(std::uint64_t);
            im.offsets = static_cast<std::uint64_t*>(std::malloc(tableBytes));
            im.counts = static_cast<std::uint64_t*>(std::malloc(tableBytes));
            if (im.offsets == nullptr || im.counts == nullptr)
                return fail(Status::OutOfMemory, "image %u: no memory for the block tables", id);
            im.blockCount = blockCount;
            if ((s = readUInts(offsets, 0, blockCount, im.offsets)) != Status::Ok) return s;
            if ((s = readUInts(counts, 0, blockCount, im.counts)) != Status::Ok) return s;
            if (!tiled && (s = virtualStrips(im, rowsPerStrip, planar == 1)) != Status::Ok) return s;
        }

        return index == 0 ? parseGeo(ifd) : Status::Ok;
    }

    // GDAL does not expose a large single strip as one block; ReadBlock follows two rules,
    // mirrored here so block sizes and contents stay the same as GDAL's:
    //  1. libtiff "strip chopping": one uncompressed pixel-interleaved strip of more than
    //     8192 bytes is presented as virtual strips of at most 8192 bytes (whole rows).
    //  2. GDAL "split" mode: an 8-bit image still in one strip (per plane) with more than
    //     2000 rows is presented row by row (block height 1).
    // Not mirrored: libtiff's re-chopping of strips larger than 2 GB.
    Status virtualStrips(Image& im, std::uint64_t rowsPerStripTag, bool contiguous) noexcept {
        ImageInfo& in = im.info;
        const unsigned sampleBytes = dataTypeSize(in.dataType);
        if (contiguous && im.blockCount == 1) {
            const std::uint64_t rowBytes = static_cast<std::uint64_t>(in.width) * in.bands * sampleBytes;
            const std::uint64_t rows = rowBytes > 8192 ? 1 : 8192 / rowBytes;
            const std::uint64_t strips = (in.height + rows - 1) / rows;
            const std::uint64_t stripBytes = rows * rowBytes;
            std::uint64_t offset = im.offsets[0], left = im.counts[0];
            bool chop = rows < rowsPerStripTag && offset <= std::numeric_limits<std::uint64_t>::max() - left;
            // As libtiff: a huge table only if the file is really that large.
            if (strips > 1000000 && (offset >= size_ || stripBytes > (size_ - offset) / (strips - 1)))
                chop = false;
            if (chop) {
                if (strips > std::numeric_limits<std::size_t>::max() / sizeof(std::uint64_t))
                    return fail(Status::OutOfMemory, "too many strips");
                const std::size_t tableBytes = static_cast<std::size_t>(strips) * sizeof(std::uint64_t);
                std::uint64_t* offsets = static_cast<std::uint64_t*>(std::malloc(tableBytes));
                std::uint64_t* counts = static_cast<std::uint64_t*>(std::malloc(tableBytes));
                if (offsets == nullptr || counts == nullptr) {
                    std::free(offsets);
                    std::free(counts);
                    return fail(Status::OutOfMemory, "no memory for the strip tables");
                }
                for (std::uint64_t i = 0; i < strips; ++i) {
                    const std::uint64_t n = stripBytes < left ? stripBytes : left;
                    counts[i] = n;
                    offsets[i] = n != 0 ? offset : 0;
                    offset += n;
                    left -= n;
                }
                std::free(im.offsets);
                std::free(im.counts);
                im.offsets = offsets;
                im.counts = counts;
                im.blockCount = strips;
                in.blockHeight = static_cast<std::uint32_t>(rows < in.height ? rows : in.height);
                in.blocksY = static_cast<std::uint32_t>(strips);
                in.blockBytes = static_cast<std::uint64_t>(in.width) * in.blockHeight * sampleBytes;
            }
        }
        if (in.bitsPerSample == 8 && in.blockHeight == in.height && in.height > 2000) {
            im.split = true;
            in.blockHeight = 1;
            in.blocksY = in.height;
            in.blockBytes = in.width;
        }
        return Status::Ok;
    }

    // Georeferencing, nodata and GDAL metadata of the main image.
    Status parseGeo(const Ifd& ifd) noexcept {
        Entry e;
        Status s;
        if (find(ifd, kGdalNoData, e)) {
            if (e.type != 2) return fail(Status::Corrupt, "GDAL_NODATA is not ASCII");
            const std::size_t n = e.count < sizeof noDataText_ - 1
                                      ? static_cast<std::size_t>(e.count) : sizeof noDataText_ - 1;
            if ((s = entryBytes(e, 0, noDataText_, n)) != Status::Ok) return s;
            noDataText_[n] = '\0';
            geo_.hasNoData = parseDouble(noDataText_, geo_.noData);
        }
        if (find(ifd, kGdalMetadata, e)) {
            if (e.type != 2) return fail(Status::Corrupt, "GDAL_METADATA is not ASCII");
            std::uint64_t bytes = 0, at = 0;
            bool inlined = false;
            if ((s = entryData(e, bytes, inlined, at)) != Status::Ok) return s;
            if (bytes >= std::numeric_limits<std::size_t>::max())
                return fail(Status::OutOfMemory, "GDAL_METADATA too large");
            metadata_ = static_cast<char*>(std::malloc(static_cast<std::size_t>(bytes) + 1));
            if (metadata_ == nullptr) return fail(Status::OutOfMemory, "no memory for GDAL_METADATA");
            if ((s = entryBytes(e, 0, metadata_, static_cast<std::size_t>(bytes))) != Status::Ok) return s;
            metadata_[bytes] = '\0';
        }
        if (find(ifd, kGeoKeyDirectory, e)) {
            std::uint64_t bytes = 0, at = 0;
            bool inlined = false;
            if (e.type != 3) return fail(Status::Corrupt, "GeoKeyDirectory is not of type SHORT");
            if ((s = entryData(e, bytes, inlined, at)) != Status::Ok) return s;
            if (bytes > std::numeric_limits<std::size_t>::max() / 2)
                return fail(Status::OutOfMemory, "GeoKeyDirectory too large");
            const std::size_t n = static_cast<std::size_t>(e.count);
            geoKeys_ = static_cast<std::uint16_t*>(std::malloc((n + 1) * sizeof(std::uint16_t)));
            if (geoKeys_ == nullptr) return fail(Status::OutOfMemory, "no memory for the GeoKeyDirectory");
            for (std::size_t i = 0; i < n; ++i) {
                std::uint64_t v = 0;
                if ((s = readUInts(e, i, 1, &v)) != Status::Ok) return s;
                geoKeys_[i] = static_cast<std::uint16_t>(v);
            }
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

    // --- state ---------------------------------------------------------------------------

    Source* src_ = nullptr;
    FileSource file_;
    MemorySource memory_;
    std::uint64_t size_ = 0;
    bool big_ = false;
    bool le_ = true;

    Image* images_ = nullptr;
    std::size_t imageCount_ = 0;

    GeoInfo geo_{};
    char noDataText_[64] = {0};
    char* metadata_ = nullptr;
    std::uint16_t* geoKeys_ = nullptr;
    std::size_t geoKeyCount_ = 0;

    // Decode scratch: the last pixel-interleaved block read, reused across bands.
    unsigned char* scratch_ = nullptr;
    std::size_t scratchSize_ = 0;
    std::size_t cacheImage_ = 0;
    std::uint64_t cacheChunk_ = 0;
    bool cacheValid_ = false;

    char message_[256];
};

}  // namespace geotiff

#endif  // GEOTIFF_GEOTIFF_HPP
