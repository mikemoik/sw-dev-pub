# geotiff

Dependency-free GeoTIFF **block** reader in C++17, a small static library (`geotiff.h` + `geotiff.cpp`), standard library only (no libtiff, GDAL or zlib). It reads the main image of a tiled GeoTIFF as GDAL writes it — including GDAL's sparse files (`SPARSE_OK=TRUE`) — one tile at a time, the equivalent of GDAL's `ReadBlock`. No window reads, no resampling, no reprojection. Target: 64-bit little-endian Linux (standard C file I/O, no byte swapping).

**Owner:** swdevos · **Status:** tested against GDAL 3.13 (unit suite + 33-file GDAL oracle, clean under ASan/UBSan with GCC and clang) · **Version:** 0.3.0 (C++17) · **License:** MIT (repo root)

## Supported

| | |
|---|---|
| Container | classic TIFF and BigTIFF, **little endian**; **main image only** — overviews and masks in the file are ignored |
| Layout | **tiles only**, **256×256** (fixed at compile time: `geotiff::kTileSize`, CMake `-DGEOTIFF_TILE_SIZE=n`) |
| Bands | **1 band, or 3 pixel-interleaved bands (RGB)** |
| Samples | **`Byte`, `UInt16`, `Int16`** |
| Sparse | absent tiles (offset 0 / byte count 0) read back as the nodata value, or 0, with `Status::Sparse` |
| Georeferencing | geotransform (pixel scale + tiepoint, or transformation matrix; PixelIsPoint shifted like GDAL), EPSG code, nodata, raw `GDAL_METADATA` XML, GeoKeys |
| Compression | **none only** |

Everything else is refused at `open` with `Status::Unsupported` and the reason named: strips, other tile sizes, 2 or 4+ bands, band-interleaved data (`INTERLEAVE=BAND` with 3 bands), compressed files (DEFLATE, LZW, …, the codec is named), predictors, every other sample type (Int8, 32/64-bit, float, complex, 1/2/4/12-bit), YCbCr, big-endian files. Not read at all: overviews, masks, GCPs.

A file that fits: `gdal_translate -co TILED=YES in.tif out.tif` (256×256 tiles, pixel-interleaved and uncompressed are GDAL's defaults).

Dropped on purpose (project constraints): strips, band-interleaved files and free tile sizes after 0.1.0; overviews, masks, big-endian files and the other sample types after 0.2.1. `readBlock` lost its image argument in 0.3.0, and the single header `geotiff.hpp` became `geotiff.h` + `src/geotiff.cpp`.

## Use

```cpp
#include "geotiff/geotiff.h"

geotiff::Reader reader;
if (reader.open("dem.tif") != geotiff::Status::Ok) {          // or open(data, size) / open(Source&)
    std::puts(reader.message());
    return 1;
}
const geotiff::ImageInfo& image = reader.image();             // width, height, blocksX/Y, bands, dataType
std::vector<std::int16_t> block(geotiff::kTileSamples);       // image.dataType == DataType::Int16
for (std::uint32_t by = 0; by < image.blocksY; ++by)
    for (std::uint32_t bx = 0; bx < image.blocksX; ++bx) {
        const geotiff::Status s = reader.readBlock(bx, by, /*band*/ 0, block.data(), image.blockBytes);
        if (!geotiff::ok(s)) { std::puts(reader.message()); return 1; }
        // s == Status::Sparse: the block is not in the file, `block` holds nodata / 0
    }
const geotiff::GeoInfo& geo = reader.geo();                   // geoTransform[6], epsg, noData, pixelIsPoint
```

- A block is one tile of one band: `kTileSize × kTileSize` samples (`kTileSamples`, `ImageInfo::blockBytes` bytes), row by row. Edge tiles are full size.
- `blockPresent(bx, by)` answers without reading.
- No exceptions, no RTTI: every call returns a `geotiff::Status`, the text is in `message()`; builds with `-fno-exceptions -fno-rtti`. Corrupt input gives `Status::Corrupt`.
- I/O goes through `geotiff::Source` (`size()`, `readAt(offset, dst, size)`); `FileSource` (stdio) and `MemorySource` are included, your own can wrap mmap or another file system.
- Memory: everything is allocated at `open` — the tile tables, plus one tile buffer for 3-band files (reading the three bands of a tile costs one file read). One `Reader` per thread.

CMake: `add_subdirectory(geotiff)` or `find_package(geotiff)` after `cmake --install`, then `target_link_libraries(app PRIVATE geotiff::geotiff)`. Without CMake: compile `src/geotiff.cpp` with `-Iinclude` into your program.

## Build & test (from this directory)

```sh
cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# sanitizers: presets asan (g++) and asan-clang (clang++)
```

| Test | What |
|---|---|
| `geotiff.unit` | `tests/geotiff_test.cpp`: an in-test TIFF writer builds files in memory across bands × type × BigTIFF × sparse, plus the constraints above, georeferencing, nodata and unsupported files. No Python. |
| `geotiff.unit_small_tiles` | the same source built with `GEOTIFF_TILE_SIZE=16`, plus every truncation and ~100 000 byte mutations of three files |
| `geotiff.no_exceptions` | header and source contain no `throw` / `try` / `catch` / RTTI keyword |
| `geotiff.knowledge` | `llm/knowledge.md` agrees with the code (tag numbers, function names, tile size) |
| `geotiff.oracle_*` | only if `python3 -c "from osgeo import gdal"` works (system `gdal` + `python-gdal`): `tests/oracle_generate.py` writes 33 files with GDAL and dumps the CRC-32 of every block from GDAL's `ReadBlock` plus the `gdalinfo` values into the build directory (~26 MB); `tests/oracle_check.cpp` compares, and checks that 8 compressed files and 15 files outside the constraints are refused. |
| `geotiff.example_info` | `examples/geotiff_info.cpp FILE.tif` on an oracle file |

## Maintaining with a local LLM

`llm/knowledge.md` holds what the code relies on but does not explain — the project constraints, the TIFF container, the tags, tiles and sparse files, GeoTIFF keys, GDAL's behaviour — for maintenance without internet access. Give it to the chat together with `geotiff.h` and `geotiff.cpp`.
