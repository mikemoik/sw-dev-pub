# geotiff

Dependency-free GeoTIFF **block** reader in C++17, one header, standard library only (no libtiff, GDAL or zlib). It reads GeoTIFFs as GDAL writes them — including GDAL's sparse files (`SPARSE_OK=TRUE`) — one block at a time, the equivalent of GDAL's `ReadBlock`. No window reads, no resampling, no reprojection.

**Owner:** swdevos · **Status:** new, tested against GDAL 3.13 (unit suite + 499-file GDAL oracle, clean under ASan/UBSan with GCC and clang) · **Version:** 0.1.0 (C++17) · **License:** MIT (repo root)

## Supported

| | |
|---|---|
| Container | classic TIFF and BigTIFF, little and big endian, all IFDs (main image, overviews, masks) |
| Layout | tiles and strips, pixel-interleaved and band-interleaved (`INTERLEAVE=PIXEL` / `BAND`) |
| Samples | `Byte`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `UInt64`, `Int64`, `Float32`, `Float64` |
| Sparse | absent blocks (offset 0 / byte count 0) read back as the nodata value, or 0, with `Status::Sparse` |
| Georeferencing | geotransform (pixel scale + tiepoint, or transformation matrix; PixelIsPoint shifted like GDAL), EPSG code, nodata, raw `GDAL_METADATA` XML, GeoKeys |
| Compression | **none only** — a compressed file (DEFLATE, LZW, PackBits, JPEG, ZSTD, …) or a predictor is refused at `open` with `Status::Unsupported` and the codec named |

Not supported: 1/2/4/12-bit, 16-bit float and complex samples, YCbCr, masks (listed, not read), GCPs, libtiff's re-chopping of strips larger than 2 GB. Codecs go into one function (`decodeChunk`) without changing the API.

Block sizes and contents are GDAL's. That includes the two cases where GDAL does not show a stored strip as one block: a single uncompressed pixel-interleaved strip larger than 8192 bytes appears as virtual strips of ≤ 8192 bytes (libtiff strip chopping), and an 8-bit image in one strip with more than 2000 rows appears row by row.

## Use

```cpp
#include "geotiff/geotiff.hpp"

geotiff::Reader reader;
if (reader.open("dem.tif") != geotiff::Status::Ok) {          // or open(data, size) / open(Source&)
    std::puts(reader.message());
    return 1;
}
const geotiff::ImageInfo& image = reader.image(0);            // 0 = main image
std::vector<float> block(image.blockBytes / sizeof(float));   // image.dataType == DataType::Float32
for (std::uint32_t by = 0; by < image.blocksY; ++by)
    for (std::uint32_t bx = 0; bx < image.blocksX; ++bx) {
        const geotiff::Status s = reader.readBlock(0, bx, by, /*band*/ 0, block.data(), image.blockBytes);
        if (!geotiff::ok(s)) { std::puts(reader.message()); return 1; }
        // s == Status::Sparse: the block is not in the file, `block` holds nodata / 0
    }
const geotiff::GeoInfo& geo = reader.geo();                   // geoTransform[6], epsg, noData, pixelIsPoint
```

- A block is `blockWidth × blockHeight` samples of one band, row by row, in host byte order. Edge tiles are full size; rows of the last strip beyond the image are 0.
- Overviews: `overviewCount()`, `overviewImage(k)` gives the image index for `readBlock`.
- `blockPresent(image, bx, by, band)` and `blockLocation(...)` answer without reading.
- No exceptions, no RTTI: every call returns a `geotiff::Status`, the text is in `message()`; builds with `-fno-exceptions -fno-rtti`. Corrupt input gives `Status::Corrupt`.
- I/O goes through `geotiff::Source` (`size()`, `readAt(offset, dst, size)`); `FileSource` (stdio) and `MemorySource` are included, your own can wrap mmap or another file system.
- Memory: the block tables at `open`, plus one reusable block buffer for pixel-interleaved multi-band files. One `Reader` per thread.

CMake: `add_subdirectory(geotiff)` or `find_package(geotiff)` after `cmake --install`, then `target_link_libraries(app PRIVATE geotiff::geotiff)`. Or copy `include/geotiff/geotiff.hpp`.

## Build & test (from this directory)

```sh
cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# sanitizers: presets asan (g++) and asan-clang (clang++)
```

| Test | What |
|---|---|
| `geotiff.unit` | `tests/geotiff_test.cpp`: an in-test TIFF writer builds files in memory across layout × interleave × type × byte order × BigTIFF × sparse, plus georeferencing, nodata, overviews, unsupported files, and every truncation and ~100 000 byte mutations of three files. No Python. |
| `geotiff.no_exceptions` | the header contains no `throw` / `try` / `catch` / RTTI keyword |
| `geotiff.oracle_*` | only if `python3 -c "from osgeo import gdal"` works (system `gdal` + `python-gdal`): `tests/oracle_generate.py` writes 499 files with GDAL and dumps every block with GDAL's `ReadBlock` plus the `gdalinfo` values into the build directory; `tests/oracle_check.cpp` compares byte for byte and checks that compressed files are refused. |
| `geotiff.example_info` | `examples/geotiff_info.cpp FILE.tif` on an oracle file |
