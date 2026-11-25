// geotiff.h — dependency-free GeoTIFF tile reader, C++17. Implementation: src/geotiff.cpp.
//
// Reads the main image of a GeoTIFF as GDAL writes it, tile by tile (the equivalent of
// GDAL's ReadBlock), with its georeferencing, nodata value and GDAL metadata. Classic TIFF
// and BigTIFF, GDAL sparse files (SPARSE_OK=TRUE: absent tiles read back as nodata or 0).
//
// Project constraints — everything else is refused at open() with Status::Unsupported:
//   - little-endian files (and a little-endian 64-bit host: Linux x86-64 / AArch64)
//   - tiles only, no strips
//   - tiles of kTileSize x kTileSize pixels, fixed at compile time (GEOTIFF_TILE_SIZE, 256)
//   - 1 band, or 3 pixel-interleaved bands (RGB); no band-interleaved data
//   - samples Byte, UInt16 or Int16
//   - uncompressed data, no predictor
// Only the first image directory is read: overviews and masks in the file are ignored.
//
// No exceptions, no RTTI: every fallible call returns a geotiff::Status, the text for
// the last failure is in Reader::message(). Standard library only.
//
// A Reader is not thread-safe; use one Reader per thread.
//
// SPDX-License-Identifier: MIT
#ifndef GEOTIFF_GEOTIFF_H
#define GEOTIFF_GEOTIFF_H

#include <cstddef>
#include <cstdint>
#include <cstdio>

#define GEOTIFF_VERSION_MAJOR 0
#define GEOTIFF_VERSION_MINOR 3
#define GEOTIFF_VERSION_PATCH 0

// Tile width and height in pixels. The library is built for one tile size, and the code
// that uses it must see the same value: change it with the CMake variable
// GEOTIFF_TILE_SIZE, which defines the macro for the library and for everything that
// links the target geotiff::geotiff. Do not define it in a single source file.
#ifndef GEOTIFF_TILE_SIZE
#define GEOTIFF_TILE_SIZE 256
#endif

namespace geotiff {

constexpr std::uint32_t kTileSize = GEOTIFF_TILE_SIZE;
static_assert(GEOTIFF_TILE_SIZE >= 1 && GEOTIFF_TILE_SIZE <= 4096, "GEOTIFF_TILE_SIZE must be 1..4096");
// Samples in one block of one band: readBlock needs kTileSamples * sample size bytes.
constexpr std::size_t kTileSamples = static_cast<std::size_t>(kTileSize) * kTileSize;

// ---------------------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------------------

enum class Status : std::uint8_t {
    Ok = 0,
    Sparse,         // readBlock: the block is absent in the file; buffer holds nodata / 0
    Io,             // the file cannot be opened or read
    NotTiff,        // no TIFF / BigTIFF header
    Corrupt,        // inconsistent or out-of-file structure
    Unsupported,    // valid TIFF outside the project constraints (strips, tile size, compression, ...)
    OutOfRange,     // block or band index out of range
    BufferTooSmall, // caller buffer smaller than ImageInfo::blockBytes
    OutOfMemory,
    NotOpen,
};

// True for the two non-failure results of readBlock.
constexpr bool ok(Status s) noexcept { return s == Status::Ok || s == Status::Sparse; }

const char* statusName(Status s) noexcept;

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
    bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept override;

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

    bool open(const char* path) noexcept;
    void close() noexcept;
    std::uint64_t size() const noexcept override { return size_; }
    bool readAt(std::uint64_t offset, void* dst, std::size_t size) noexcept override;

private:
    bool seek(std::uint64_t offset, int whence) noexcept;
    std::int64_t tell() noexcept;

    std::FILE* file_ = nullptr;
    std::uint64_t size_ = 0;
};

// ---------------------------------------------------------------------------------------
// Image description
// ---------------------------------------------------------------------------------------

enum class DataType : std::uint8_t { Unknown = 0, UInt8, UInt16, Int16 };

constexpr unsigned dataTypeSize(DataType t) noexcept {
    return t == DataType::Unknown ? 0u : t == DataType::UInt8 ? 1u : 2u;
}

// GDAL's names (Byte, UInt16, Int16).
const char* dataTypeName(DataType t) noexcept;

// The main image of the file: its first image directory. Further directories (overviews,
// masks) are not read.
struct ImageInfo {
    std::uint32_t width;
    std::uint32_t height;
    std::uint32_t blocksX;   // tiles per row
    std::uint32_t blocksY;   // tile rows
    std::uint16_t bands;     // 1 or 3
    DataType dataType;
    std::size_t blockBytes;  // one band of one tile = buffer size for readBlock
};

// Georeferencing of the image, as GDAL reports it.
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
    Status open(const char* path) noexcept;
    // Open a file image held in memory; the bytes must outlive the Reader's use of them.
    Status open(const void* data, std::size_t size) noexcept;
    // Open on a caller-owned source (mmap, custom file system, ...).
    Status open(Source& source) noexcept;
    void close() noexcept;

    bool isOpen() const noexcept { return src_ != nullptr; }
    // Text for the last failed call ("" if none).
    const char* message() const noexcept { return message_; }

    bool bigTiff() const noexcept { return big_; }
    // All zero while no file is open.
    const ImageInfo& image() const noexcept { return info_; }
    const GeoInfo& geo() const noexcept { return geo_; }
    // Raw GDAL_METADATA XML ("" if the tag is absent).
    const char* gdalMetadata() const noexcept { return metadata_ ? metadata_ : ""; }
    // A GeoKey stored as a SHORT in the GeoKey directory (e.g. 3072 ProjectedCSType).
    bool geoKey(std::uint16_t id, std::uint16_t& value) const noexcept;

    // False for an absent (sparse) tile and for an index out of range.
    bool blockPresent(std::uint32_t bx, std::uint32_t by) const noexcept;

    // Read tile (bx, by) of `band` (0-based) into `buffer` (>= ImageInfo::blockBytes):
    // kTileSize x kTileSize samples of that band, row by row — the same bytes GDAL's
    // ReadBlock gives.
    //   Status::Ok      tile read from the file
    //   Status::Sparse  tile absent: buffer filled with the nodata value, or 0
    //   anything else   failure, buffer contents unspecified
    Status readBlock(std::uint32_t bx, std::uint32_t by, unsigned band, void* buffer,
                     std::size_t bufferSize) noexcept;

private:
    struct Entry;  // one tag of the image directory
    struct Ifd;    // the image directory in memory

#if defined(__GNUC__) || defined(__clang__)
    __attribute__((format(printf, 3, 4)))
#endif
    Status fail(Status s, const char* format, ...) noexcept;
    std::uint64_t tileIndex(std::uint32_t bx, std::uint32_t by) const noexcept;
    void release() noexcept;

    Status readTile(std::uint32_t bx, std::uint32_t by, unsigned char* dst, std::size_t size) noexcept;
    void fillNoData(unsigned char* out) const noexcept;

    Status openSource(Source& source) noexcept;
    Status parse() noexcept;
    Status loadIfd(std::uint64_t offset, Ifd& ifd) noexcept;
    bool find(const Ifd& ifd, std::uint16_t tag, Entry& e) const noexcept;
    Status entryData(const Entry& e, std::uint64_t& bytes, bool& inlined, std::uint64_t& offset) noexcept;
    Status entryBytes(const Entry& e, std::uint64_t start, void* dst, std::size_t size) noexcept;
    Status readUInts(const Entry& e, std::uint64_t start, std::uint64_t n, std::uint64_t* out) noexcept;
    Status readDoubles(const Entry& e, std::uint64_t n, double* out) noexcept;
    Status scalar(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t& v,
                  bool* found = nullptr) noexcept;
    Status perSample(const Ifd& ifd, std::uint16_t tag, std::uint64_t fallback, std::uint64_t samples,
                     std::uint64_t& v, bool& uniform) noexcept;
    Status parseImage(std::uint64_t ifdOffset) noexcept;
    Status parseGeo(const Ifd& ifd) noexcept;

    Source* src_ = nullptr;
    FileSource file_;
    MemorySource memory_;
    std::uint64_t size_ = 0;
    bool big_ = false;

    ImageInfo info_{};
    std::uint64_t* offsets_ = nullptr;  // file offset per tile, 0 = absent
    std::uint64_t* counts_ = nullptr;   // stored bytes per tile, 0 = absent

    GeoInfo geo_{};
    char* metadata_ = nullptr;
    std::uint16_t* geoKeys_ = nullptr;
    std::size_t geoKeyCount_ = 0;

    // The last 3-band tile read, reused across bands (3 * blockBytes, 3-band files only).
    unsigned char* scratch_ = nullptr;
    std::uint64_t cacheTile_ = 0;
    bool cacheValid_ = false;

    char message_[256];
};

}  // namespace geotiff

#endif  // GEOTIFF_GEOTIFF_H
