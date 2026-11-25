# geotiff

Dependency-free GeoTIFF **block** reader in C++17, one header, standard library only (no libtiff, GDAL or zlib). It reads tiled GeoTIFFs as GDAL writes them — including GDAL's sparse files (`SPARSE_OK=TRUE`) — one tile at a time, the equivalent of GDAL's `ReadBlock`. No window reads, no resampling, no reprojection.

**Owner:** swdevos · **Status:** tested against GDAL 3.13 (unit suite + 89-file GDAL oracle, clean under ASan/UBSan with GCC and clang) · **Version:** 0.2.0 (C++17) · **License:** MIT (repo root)

## Supported

| | |
|---|---|
| Container | classic TIFF and BigTIFF, little and big endian, all IFDs (main image, overviews, masks) |
| Layout | **tiles only**, **256×256** (fixed at compile time: `geotiff::kTileSize`, `-DGEOTIFF_TILE_SIZE=n`) |
| Bands | **1 band, or 3 pixel-interleaved bands (RGB)** |
| Samples | `Byte`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `UInt64`, `Int64`, `Float32`, `Float64` |
| Sparse | absent tiles (offset 0 / byte count 0) read back as the nodata value, or 0, with `Status::Sparse` |
| Georeferencing | geotransform (pixel scale + tiepoint, or transformation matrix; PixelIsPoint shifted like GDAL), EPSG code, nodata, raw `GDAL_METADATA` XML, GeoKeys |
| Compression | **none only** |

Everything else is refused at `open` with `Status::Unsupported` and the reason named: strips, other tile sizes, 2 or 4+ bands, band-interleaved data (`INTERLEAVE=BAND` with 3 bands), compressed files (DEFLATE, LZW, …, the codec is named), predictors, 1/2/4/12-bit, 16-bit float and complex samples, YCbCr. An overview or mask outside the subset is listed, not read. Not read at all: GCPs, mask contents.

A file that fits: `gdal_translate -co TILED=YES in.tif out.tif` (256×256 tiles, pixel-interleaved and uncompressed are GDAL's defaults).

Version 0.1.0 also read strips, band-interleaved files and any tile size; 0.2.0 dropped them on purpose (project constraints).

## Use

```cpp
#include "geotiff/geotiff.hpp"

geotiff::Reader reader;
if (reader.open("dem.tif") != geotiff::Status::Ok) {          // or open(data, size) / open(Source&)
    std::puts(reader.message());
    return 1;
}
const geotiff::ImageInfo& image = reader.image(0);            // 0 = main image
std::vector<float> block(geotiff::kTileSamples);              // image.dataType == DataType::Float32
for (std::uint32_t by = 0; by < image.blocksY; ++by)
    for (std::uint32_t bx = 0; bx < image.blocksX; ++bx) {
        const geotiff::Status s = reader.readBlock(0, bx, by, /*band*/ 0, block.data(), image.blockBytes);
        if (!geotiff::ok(s)) { std::puts(reader.message()); return 1; }
        // s == Status::Sparse: the block is not in the file, `block` holds nodata / 0
    }
const geotiff::GeoInfo& geo = reader.geo();                   // geoTransform[6], epsg, noData, pixelIsPoint
```

- A block is one tile of one band: `kTileSize × kTileSize` samples (`kTileSamples`, `ImageInfo::blockBytes` bytes), row by row, in host byte order. Edge tiles are full size.
- Overviews: `overviewCount()`, `overviewImage(k)` gives the image index for `readBlock`.
- `blockPresent(image, bx, by, band)` and `blockLocation(...)` answer without reading.
- No exceptions, no RTTI: every call returns a `geotiff::Status`, the text is in `message()`; builds with `-fno-exceptions -fno-rtti`. Corrupt input gives `Status::Corrupt`.
- I/O goes through `geotiff::Source` (`size()`, `readAt(offset, dst, size)`); `FileSource` (stdio) and `MemorySource` are included, your own can wrap mmap or another file system.
- Memory: the tile tables at `open`, plus one reusable tile buffer for 3-band files (reading the three bands of a tile costs one file read). One `Reader` per thread.

CMake: `add_subdirectory(geotiff)` or `find_package(geotiff)` after `cmake --install`, then `target_link_libraries(app PRIVATE geotiff::geotiff)`. Or copy `include/geotiff/geotiff.hpp`.

## Build & test (from this directory)

```sh
cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# sanitizers: presets asan (g++) and asan-clang (clang++)
```

| Test | What |
|---|---|
| `geotiff.unit` | `tests/geotiff_test.cpp`: an in-test TIFF writer builds files in memory across bands × type × byte order × BigTIFF × sparse, plus the constraints above, georeferencing, nodata, overviews and unsupported files. No Python. |
| `geotiff.unit_small_tiles` | the same source built with `GEOTIFF_TILE_SIZE=16`, plus every truncation and ~100 000 byte mutations of three files |
| `geotiff.no_exceptions` | the header contains no `throw` / `try` / `catch` / RTTI keyword |
| `geotiff.knowledge` | `llm/knowledge.md` agrees with the header (tag numbers, function names, tile size) |
| `geotiff.oracle_*` | only if `python3 -c "from osgeo import gdal"` works (system `gdal` + `python-gdal`): `tests/oracle_generate.py` writes 89 files with GDAL and dumps the CRC-32 of every block from GDAL's `ReadBlock` plus the `gdalinfo` values into the build directory (~120 MB); `tests/oracle_check.cpp` compares, and checks that 8 compressed files and 8 files outside the constraints are refused. |
| `geotiff.example_info` | `examples/geotiff_info.cpp FILE.tif` on an oracle file |

## Maintaining with a local LLM

`llm/knowledge.md` holds what the code relies on but does not explain — the project constraints, the TIFF container, the tags, tiles and sparse files, GeoTIFF keys, GDAL's behaviour — for maintenance without internet access. Give it to the chat together with the header.
