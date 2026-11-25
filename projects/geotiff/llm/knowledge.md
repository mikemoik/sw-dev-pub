# geotiff — knowledge for maintaining the reader offline

Background on TIFF, GeoTIFF and GDAL that `include/geotiff/geotiff.hpp` relies on but
does not explain. Written for a maintainer (human or local LLM) without internet access:
give it this file together with the header. It holds only what this reader needs.

Rules for this file:

- A number here must equal the number in the header. `ctest` checks the tag table and
  every function named here with `()` behind it (`geotiff.knowledge`,
  `cmake/check_knowledge.cmake`).
- "Observed" means: seen with GDAL 3.13.3 / libtiff 4.7.2 on the development host, and
  pinned by a test. Do not replace an observed fact with what a specification suggests.
- Change the code and this file in the same commit.

## 1. Project constraints

The reader is deliberately narrow. Everything outside is a **valid** file that `open`
refuses with `Status::Unsupported` and a message that names the reason. It is not
`Status::Corrupt`.

| # | Constraint | Refused | Word in the message |
|---|---|---|---|
| C1 | Tiles only | any image stored in strips | `strips` |
| C2 | Tile size fixed at compile time: `kTileSize` × `kTileSize`, `GEOTIFF_TILE_SIZE` (default 256) | every other tile size, also non-square | `tiles are not supported` |
| C3 | 1 band, or 3 bands (RGB) | 2, 4 and more samples per pixel (also RGBA) | `bands are not supported` |
| C4 | Pixel-interleaved only | 3 bands with `PlanarConfiguration` 2 (`INTERLEAVE=BAND`) | `band-interleaved` |
| C5 | Uncompressed, no predictor | every `Compression` ≠ 1, every `Predictor` ≠ 1 | codec name / `predictor` |
| C6 | Samples 8/16/32/64-bit integer, 32/64-bit float | 1/2/4/12-bit, 16-bit float, complex, mixed depths | `-bit samples` |
| C7 | No YCbCr | `PhotometricInterpretation` 6 | `YCbCr` |

Target platform: 64-bit Linux. File access is standard C only (`fopen`, `fseek`, `fread`), no
platform calls. `fseek` takes a `long`: 64 bit on the target, so any file size works. Where
`long` is 32 bit (Windows, 32-bit systems) offsets past 2 GB fail cleanly; do not add
`fseeko` / `_fseeki64` branches for that.

Consequences to keep in mind when changing code:

- All checks sit in one `if / else if` chain in `parseImage()`. The order is the order of
  the table rows C5, C6, C7, C1, C2, C3, C4: a compressed strip file reports the codec,
  not the strips. Tests rely on that order.
- The rule applies **per image**. If the main image (image 0) is outside the subset,
  `open` fails. An overview or mask outside the subset stays listed with
  `ImageInfo::status == Unsupported` and `blockBytes == 0`; `readBlock()` on it returns
  `Unsupported`. The main image stays readable.
- "3 bands" means `SamplesPerPixel` = 3. The photometric value is not checked (except
  C7): GDAL writes 3 Byte bands as RGB (2), but 3 bands of other types as MinIsBlack (1)
  plus `ExtraSamples` (observed for UInt16 and Float32). Both are read.
- For one band `PlanarConfiguration` has no meaning. GDAL writes 2 for a single band with
  `INTERLEAVE=BAND` (observed), so C4 applies to 3 bands only.
- A block of one band is always `kTileSamples` = `kTileSize`² samples.
  `ImageInfo::blockBytes` = `kTileSamples` × sample size; a caller may use a fixed buffer.
- `GEOTIFF_TILE_SIZE` exists so the unit tests can run with 16×16 tiles (small files,
  every byte mutated). The product is built with 256. It must be the same in every
  translation unit; allowed range 1..4096.
- Strips, band-interleaved files and free tile sizes were supported up to release
  `geotiff-v0.1.0` (incl. libtiff strip chopping and GDAL split mode). That code was
  removed on purpose; the tag is the place to look if it is ever needed again.

Files that fit (GDAL): `gdal_translate -co TILED=YES in.tif out.tif` (tile size 256 and
`INTERLEAVE=PIXEL` are the GTiff defaults, no compression), optionally
`-co SPARSE_OK=TRUE`, `-co BIGTIFF=YES`. Files that do not fit: GTiff without
`TILED=YES` (strips), the COG driver with its defaults (LZW, 512×512 tiles), RGBA.

## 2. TIFF container

All multi-byte values in the file use the byte order of the header. `rd16()`, `rd32()`,
`rd64()` read them.

Header:

| | Classic TIFF | BigTIFF |
|---|---|---|
| bytes 0–1 | `II` (little endian) or `MM` (big endian) | same |
| bytes 2–3 | 42 | 43 |
| then | bytes 4–7: offset of the first IFD | bytes 4–5: 8 (offset size), 6–7: 0, 8–15: offset of the first IFD |

Image file directory (IFD), one per image — `ifdLayout()`:

| | Classic | BigTIFF |
|---|---|---|
| entry count | 2 bytes | 8 bytes |
| entry | 12 bytes: tag 2, type 2, count 4, value/offset 4 | 20 bytes: tag 2, type 2, count 8, value/offset 8 |
| after the entries | 4 bytes: offset of the next IFD, 0 = last | 8 bytes |

- `count` is the number of values, not bytes. Data size = count × type size.
- If the data fits the value/offset field (≤ 4 bytes classic, ≤ 8 BigTIFF) it is stored
  **in** the field, left-aligned. Otherwise the field holds the file offset of the data —
  `entryData()`, `entryBytes()`.
- Entries are sorted by tag in a valid file; `find()` does not rely on it.
- Field types (`typeSize()`): 1 BYTE, 2 ASCII, 6 SBYTE, 7 UNDEFINED = 1 byte; 3 SHORT,
  8 SSHORT = 2; 4 LONG, 9 SLONG, 11 FLOAT, 13 IFD = 4; 5 RATIONAL, 10 SRATIONAL,
  12 DOUBLE, 16 LONG8, 17 SLONG8, 18 IFD8 = 8.
- A writer may choose any unsigned type for a number (width as SHORT or LONG, offsets as
  LONG or LONG8). `readUInts()` therefore accepts types 1, 3, 4, 13, 16, 18.
- The IFD chain can be corrupt or loop: `parse()` stops at `kMaxImages`.

## 3. Tags the reader uses

The names are the constants in the header. Default = value if the tag is absent.

| Constant | Tag | Meaning | Default |
|---|---|---|---|
| `kNewSubfileType` | 254 | bit 0 (1) = reduced-resolution image (overview), bit 2 (4) = mask | 0 |
| `kImageWidth` | 256 | pixels per row | required |
| `kImageLength` | 257 | rows | required |
| `kBitsPerSample` | 258 | one value per sample (or one for all) | 1 |
| `kCompression` | 259 | 1 = none; see below | 1 |
| `kPhotometric` | 262 | 0 MinIsWhite, 1 MinIsBlack, 2 RGB, 3 palette, 6 YCbCr | 0 |
| `kSamplesPerPixel` | 277 | bands | 1 |
| `kPlanarConfig` | 284 | 1 = pixel-interleaved (contiguous), 2 = band-interleaved (separate) | 1 |
| `kPredictor` | 317 | 1 none, 2 horizontal, 3 floating point | 1 |
| `kTileWidth` | 322 | present = the image is tiled | — |
| `kTileLength` | 323 | tile height | — |
| `kTileOffsets` | 324 | file offset of each tile | required |
| `kTileByteCounts` | 325 | stored bytes of each tile | required |
| `kSampleFormat` | 339 | 1 unsigned, 2 signed, 3 IEEE float, 4 undefined (read as unsigned, like GDAL), 5/6 complex | 1 |
| `kModelPixelScale` | 33550 | GeoTIFF, 3 DOUBLE: scale x, y, z | — |
| `kModelTiepoint` | 33922 | GeoTIFF, 6 DOUBLE per point: i, j, k, x, y, z | — |
| `kModelTransformation` | 34264 | GeoTIFF, 16 DOUBLE: 4×4 matrix, row by row | — |
| `kGeoKeyDirectory` | 34735 | GeoTIFF, SHORT array, see section 6 | — |
| `kGdalMetadata` | 42112 | GDAL, ASCII: XML | — |
| `kGdalNoData` | 42113 | GDAL, ASCII: the nodata value as text | — |

Not read on purpose: `StripOffsets` 273, `RowsPerStrip` 278, `StripByteCounts` 279 (an
image without `TileWidth` is a strip image → C1), `ExtraSamples` 338, the GeoKey
parameter tags `GeoDoubleParams` 34736 and `GeoAsciiParams` 34737 (only SHORT keys are
needed), colour maps.

Compression codes the reader names when it refuses a file (`compressionName()`): 2–4
CCITT, 5 LZW, 6 and 7 JPEG, 8 and 32946 DEFLATE, 32773 PackBits, 34712 JPEG 2000,
34887 LERC, 34925 LZMA, 50000 ZSTD, 50001 WebP, 50002 and 52546 JPEG XL.

## 4. Tiles

- The image is cut into a grid of `kTileSize` × `kTileSize` tiles, starting at the top
  left. `blocksX` = ceil(width / tile width), `blocksY` = ceil(height / tile height).
- Tiles are numbered row by row: index = `by` × `blocksX` + `bx` — `lookup()`.
  `TileOffsets[index]` and `TileByteCounts[index]` describe the tile.
- **Every tile is stored full size**, also at the right and bottom edge and when the
  image is smaller than one tile. The pixels beyond the image are padding with no defined
  content; the reader returns them as stored, like GDAL's `ReadBlock`.
- Uncompressed tile size = `kTileSamples` × bands × sample bytes. `decodeChunk()` rejects
  a smaller `TileByteCounts` value (`Corrupt`) and reads exactly that many bytes.
- Pixel-interleaved 3-band tile: samples in the order R G B R G B …, row by row. One
  stored tile holds all three bands. `readBlock()` returns **one band**: it decodes the
  tile into a scratch buffer once, keeps it (one-tile cache), and `deinterleave()` picks
  every third sample. Reading band 0, 1, 2 of the same tile costs one file read.
- Samples are stored in file byte order; `readBlock()` returns host byte order
  (`swapSamples()`, or inside `deinterleave()`).

### Sparse files (GDAL `SPARSE_OK=TRUE`)

- A tile that was never written has **offset 0 and byte count 0**. The reader treats
  offset 0 *or* byte count 0 as absent.
- `readBlock()` then fills the buffer with the nodata value converted to the sample type,
  or 0 if the file has no nodata value, and returns `Status::Sparse` (`ok()` is true for
  it). This is what GDAL's `ReadBlock` returns — `fillNoData()`.
- With 3 bands a tile is present as soon as one band was written; the other bands of
  that tile are then stored too, with whatever the writer put there.
- `blockPresent()` and `blockLocation()` answer from the tables without file access.

## 5. Samples

| `DataType` | GDAL name | Bits | `SampleFormat` |
|---|---|---|---|
| `UInt8` | Byte | 8 | 1 (or 4) |
| `Int8` | Int8 | 8 | 2 |
| `UInt16` / `Int16` | UInt16 / Int16 | 16 | 1 / 2 |
| `UInt32` / `Int32` | UInt32 / Int32 | 32 | 1 / 2 |
| `UInt64` / `Int64` | UInt64 / Int64 | 64 | 1 / 2 |
| `Float32` / `Float64` | Float32 / Float64 | 32 / 64 | 3 |

`BitsPerSample` and `SampleFormat` hold one value per band, but a writer may give a single
value for all bands — `perSample()`. Bands with different depths or formats → C6.

## 6. Images in one file

GDAL stores overviews and masks as further IFDs in the same chain.

- Image 0 is the main image. `NewSubfileType` bit 0 marks an overview, bit 2 a mask; an
  overview of a mask has both (5).
- Overviews come in the order they were built, usually largest first. Each has its own
  size and its own tile tables; its tile size is checked against C2 like any image.
- Observed: `BuildOverviews` on a file with 256×256 tiles writes 256×256 overview tiles.
  With the configuration option `GDAL_TIFF_OVR_BLOCKSIZE=128` it writes 128×128 tiles:
  such an overview is listed but not readable.
- GDAL's internal mask (`GDAL_TIFF_INTERNAL_MASK=YES`) is a 1-bit DEFLATE image: listed
  with `mask == true`, status `Unsupported` (C5). Masks are not interpreted.
- Georeferencing, nodata and metadata are read from image 0 only — `parseGeo()`.

## 7. GeoTIFF georeferencing

### Geotransform

GDAL's six numbers: `x = gt[0] + col*gt[1] + row*gt[2]`, `y = gt[3] + col*gt[4] + row*gt[5]`,
with (col, row) the top-left **corner** of a pixel. North-up images have `gt[2] = gt[4] = 0`
and `gt[5] < 0`.

Derived as GDAL does — `parseGeo()`:

1. `ModelPixelScale` (≥ 2 values) and `ModelTiepoint` (≥ 6 values) present: with scale
   `(sx, sy)` and the first tiepoint `(i, j, k, x, y, z)`:
   `gt[1] = sx`, `gt[5] = -|sy|`, `gt[0] = x - i*gt[1]`, `gt[3] = y - j*gt[5]`, `gt[2] = gt[4] = 0`.
2. Else `ModelTransformation` with exactly 16 values `m`: `gt = (m[3], m[0], m[1], m[7], m[4], m[5])`.
   GDAL writes this form for rotated or sheared images.
3. Else no geotransform (`hasGeoTransform == false`).

PixelIsPoint: if `GTRasterTypeGeoKey` is 2, the tiepoint refers to the pixel **centre**.
GDAL then reports the corner: `gt[0] -= gt[1]/2 + gt[2]/2`, `gt[3] -= gt[4]/2 + gt[5]/2`.
Observed: a file with origin (8.0, 50.0), pixel size 0.001 and `AREA_OR_POINT=Point` stores
the tiepoint (8.0005, 49.9995); the reader gives back 8.0 and 50.0.

### GeoKey directory (tag 34735)

An array of SHORT values in groups of four:

- Header: `version (1), key revision (1), minor revision (0), number of keys`.
- Then one group per key: `key id, location, count, value`.
  - `location == 0`: the value is the SHORT in the fourth field (count is 1).
  - `location == 34736` / `34737`: the value lies in the DOUBLE / ASCII parameter tag at
    index `value` — not read by this reader.
- Example (observed, UTM 32N): `1 1 0 7  1024 0 1 1  1025 0 1 1  1026 34737 22 0  2049 34737 7 22  2054 0 1 9102  3072 0 1 32632  3076 0 1 9001`.
- The number of keys may be larger than the array holds in a corrupt file: `geoKey()`
  clamps it.

Keys the reader uses:

| Key id | Name | Values |
|---|---|---|
| 1024 | GTModelTypeGeoKey | 1 projected, 2 geographic, 3 geocentric |
| 1025 | GTRasterTypeGeoKey | 1 PixelIsArea (default), 2 PixelIsPoint |
| 2048 | GeographicTypeGeoKey | EPSG code of a geographic CRS (e.g. 4326) |
| 3072 | ProjectedCSTypeGeoKey | EPSG code of a projected CRS (e.g. 32632) |

`GeoInfo::epsg`: model type 1 → key 3072; model type 2 → key 2048; model type absent →
3072 if present, else 2048. The values 0 (undefined) and 32767 (user-defined) give
`epsg = 0`. Other keys are available raw through `geoKey()`.

## 8. GDAL tags

- **`GDAL_NODATA` (42113)**: ASCII text of one number for all bands, e.g. `-9999`, `nan`,
  `-inf`, `1.5e+300`, `18446744073709551615`. `GeoInfo::noData` is the value as a
  double, `noDataText()` the raw text. Text that is no number counts as "no nodata".
- Conversion to the sample type for sparse tiles, as GDAL does (`fillNoData()`,
  `testNoData()`): integers round to nearest and saturate at the type limits; NaN gives 0
  for integer types; 64-bit integers are parsed from the text, because a double is exact
  only up to 2^53; Float32 beyond its range gives ±infinity.
- **`GDAL_METADATA` (42112)**: ASCII XML,
  `<GDALMetadata>\n  <Item name="FOO">bar</Item>\n</GDALMetadata>`. Returned raw by
  `gdalMetadata()`, not parsed.
- `AREA_OR_POINT=Point` is not stored in the XML; it is `GTRasterTypeGeoKey` = 2.
- GDAL 3.13.3 quirk (test generator only): `BuildOverviews` does not return on a 64-bit
  integer band whose nodata value is no exact double. `tests/oracle_generate.py` gives
  those files no overviews.

## 9. Rules of the code

- No exceptions, no RTTI, no `new`: memory comes from `malloc` / `realloc` / `calloc` and
  every result is checked (`Status::OutOfMemory`). `geotiff.no_exceptions` fails on the
  keywords. Standard library only, C++17.
- Every fallible function returns `Status`; the text goes through `fail()` into
  `message()`.
- The file is untrusted. Before memory is sized by a number from the file, that number is
  checked against the file size (`entryData()`). Counts from the file are multiplied
  with an overflow check (`mulOverflow()`), every offset + size is tested as
  `size > fileSize - offset`.
  `testCorrupt()` truncates and mutates every byte of three files; the sanitizer presets
  must stay clean.
- `Corrupt` = the file contradicts itself or points outside itself. `Unsupported` = valid
  but outside section 1. Keep the two apart.
- `decodeChunk()` is the only place that knows about compression and predictor.

## 10. Where to change what

| Change | Place |
|---|---|
| Another tile size | build with `-DGEOTIFF_TILE_SIZE=n`; nothing else |
| Accept another band count | chain in `parseImage()`; `readBlock()` already handles any pixel-interleaved count |
| Add a codec | case in `decodeChunk()`, admit the code in `parseImage()`, add oracle files |
| Read a further tag | add the constant to the enum and to section 3, read it in `parseImage()` or `parseGeo()` |
| Report a further GeoKey | `geoKey()` already returns any SHORT key |

## 11. Tests

Run from the project directory, all three after every change:

```sh
cmake --preset dev && cmake --build --preset dev && ctest --preset dev
cmake --preset asan && cmake --build --preset asan && ctest --preset asan
cmake --preset asan-clang && cmake --build --preset asan-clang && ctest --preset asan-clang
```

| Test | Covers |
|---|---|
| `geotiff.unit` | `tests/geotiff_test.cpp` with 256×256 tiles: `testMatrix()` (bands × type × byte order × BigTIFF × sparse), `testLayouts()`, `testConstraints()` (section 1), `testGeo()`, `testNoData()`, `testOverviews()`, `testUnsupported()`, `testApi()`, `testCorrupt()` |
| `geotiff.unit_small_tiles` | the same source with `GEOTIFF_TILE_SIZE=16`, plus every truncation and byte mutation in `testCorrupt()` |
| `geotiff.no_exceptions` | no exception / RTTI keyword in the header |
| `geotiff.knowledge` | this file agrees with the header |
| `geotiff.oracle_*` | only with the Python GDAL bindings: GDAL writes files, the reader must return the same blocks (CRC-32) and metadata; compressed files and files outside section 1 must be refused |

The unit tests need no GDAL: `build()` in the test writes TIFF files in memory from an
`ImageSpec`, including files outside the subset.

## 12. Sources

Checked on the development host on 2026-11-25, not taken from memory:

- tag numbers, field types, compression codes: libtiff 4.7.2 `tiff.h`
- GeoTIFF tags and key ids: libgeotiff `xtiffio.h`, `geokeys.inc`, `geovalues.h`
- GDAL behaviour: GDAL 3.13.3 (files written with the Python bindings, dumped with
  `tiffdump` / `listgeo`), and the oracle tests
