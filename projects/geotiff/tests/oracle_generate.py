#!/usr/bin/env python3
"""Generate the GDAL oracle for geotiff.hpp.

    python3 oracle_generate.py OUTDIR

Writes GeoTIFFs with the system GDAL inside the reader's subset (256x256 tiles, 1 band or
3 pixel-interleaved bands) across data type x byte order x BigTIFF x sparse (+ nodata,
georeferencing, overviews, masks), and next to each <name>.tif

    <name>.txt     what gdalinfo reports (size, type, block, nodata, geotransform, EPSG)
    <name>.blocks  every block of every band of every level, read with GDAL's ReadBlock:
                   1 byte "present in the file" + the CRC-32 of the block bytes (4 bytes,
                   little endian), level/band/row/column order

plus index.txt (one name per line), reject.txt (compressed files: "<name> <codec>") and
outside.txt (valid files outside the subset: "<name> <word of the message>").
oracle_check (C++) reads all of it back through geotiff.hpp. Needs python-gdal only.
"""
import array
import itertools
import os
import struct
import sys
import zlib

from osgeo import gdal, osr

gdal.UseExceptions()

W, H = 300, 280   # 2 x 2 tiles, both edges cut a tile
W1, H1 = 300, 200  # 2 x 1 tiles
DTYPES = [  # GDAL name, array typecode
    ("Byte", "B"), ("Int8", "b"), ("UInt16", "H"), ("Int16", "h"), ("UInt32", "I"),
    ("Int32", "i"), ("UInt64", "Q"), ("Int64", "q"), ("Float32", "f"), ("Float64", "d"),
]
NODATA = {  # candidates per type; None = no nodata value
    "Byte": [None, 255, 0, 7], "Int8": [None, -128, 5], "UInt16": [None, 65535, 9999],
    "Int16": [None, -9999, -32768], "UInt32": [None, 4294967295, 1],
    "Int32": [None, -2147483648, -9999], "UInt64": [None, 18446744073709551615, 9007199254740993],
    "Int64": [None, -9223372036854775808, -9007199254740993],
    "Float32": [None, -9999.0, float("nan"), 1.5], "Float64": [None, -1.0e300, float("nan"), -9999.25],
}
GEO = [  # geotransform, EPSG, PixelIsPoint
    None,
    ((8.0, 0.001, 0.0, 50.0, 0.0, -0.001), 4326, False),
    ((500000.0, 2.5, 0.0, 5400000.0, 0.0, -2.5), 32632, True),
    ((1000.0, 2.0, 0.5, 2000.0, -0.5, -2.0), 3857, False),   # rotated: transformation matrix
    ((350000.5, 10.0, 0.0, 5600000.25, 0.0, -10.0), 25832, False),
]


FORMULA = {  # sample for v = 1 + 7x + 13y + 31 band; never all zero
    "B": lambda v, x: v % 251 + 1,
    "b": lambda v, x: v % 250 - 125 or 3,
    "H": lambda v, x: v * 3 % 65000 + 1,
    "h": lambda v, x: v * 3 % 60000 - 30000 or 3,
    "I": lambda v, x: v * 70001,
    "i": lambda v, x: v * 70001 - 50000000,
    "Q": lambda v, x: v * 0x100000001 + 2 ** 63,
    "q": lambda v, x: -v * 0x100000001,
    "f": lambda v, x: v * 0.25 - 100.0,
    "d": lambda v, x: v * 0.125 - 1000.0 + 1e-9 * x,
}


def values(code, band, x0, y0, w, h):
    """Deterministic samples for a window."""
    f = FORMULA[code]
    xs = range(x0, x0 + w)
    out = array.array(code)
    for y in range(y0, y0 + h):
        base = 1 + y * 13 + band * 31
        out.extend([f(base + x * 7, x) for x in xs])
    return out.tobytes()


def create(path, gdt_name, code, bands, options, sparse, nodata, geo, overviews, mask=False,
           size=(W, H)):
    gdt = gdal.GetDataTypeByName(gdt_name)
    w, h = size
    if mask:
        gdal.SetConfigOption("GDAL_TIFF_INTERNAL_MASK", "YES")
    ds = gdal.GetDriverByName("GTiff").Create(path, w, h, bands, gdt, options=options)
    if geo is not None:
        gt, epsg, point = geo
        srs = osr.SpatialReference()
        srs.ImportFromEPSG(epsg)
        ds.SetSpatialRef(srs)
        ds.SetGeoTransform(gt)
        if point:
            ds.SetMetadataItem("AREA_OR_POINT", "Point")
    bw, bh = ds.GetRasterBand(1).GetBlockSize()
    for b in range(1, bands + 1):
        band = ds.GetRasterBand(b)
        if nodata is not None:
            if gdt_name == "Int64":
                band.SetNoDataValueAsInt64(nodata)
            elif gdt_name == "UInt64":
                band.SetNoDataValueAsUInt64(nodata)
            else:
                band.SetNoDataValue(nodata)
        for by, bx in itertools.product(range((h + bh - 1) // bh), range((w + bw - 1) // bw)):
            if sparse is None or (sparse and (bx + 2 * by) % 3 == 0):
                continue  # no band written: the tile stays absent with SPARSE_OK=TRUE
            x0, y0 = bx * bw, by * bh
            ww, hh = min(bw, w - x0), min(bh, h - y0)
            band.WriteRaster(x0, y0, ww, hh, values(code, b, x0, y0, ww, hh), buf_type=gdt)
    if mask:
        ds.CreateMaskBand(gdal.GMF_PER_DATASET)
        ds.GetRasterBand(1).GetMaskBand().Fill(255)
    ds = None
    if mask:
        gdal.SetConfigOption("GDAL_TIFF_INTERNAL_MASK", None)
    if overviews:
        ds = gdal.OpenEx(path, gdal.OF_UPDATE, open_options=["SPARSE_OK=TRUE"] if sparse else [])
        ds.BuildOverviews("NEAREST", overviews)
        ds = None


def dump(path):
    """<name>.txt from gdalinfo, <name>.blocks from ReadBlock."""
    info = gdal.Info(path, format="json")
    ds = gdal.Open(path)
    band1 = ds.GetRasterBand(1)
    srs = ds.GetSpatialRef()
    epsg = int(srs.GetAuthorityCode(None) or 0) if srs is not None else 0
    b0 = info["bands"][0]
    gt = ds.GetGeoTransform(can_return_null=True)
    assert (gt is None) == ("geoTransform" not in info) or gt == (0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    if "geoTransform" in info:
        gt = info["geoTransform"]
    else:
        gt = None
    nodata = b0.get("noDataValue")
    if isinstance(nodata, str):  # "NaN"
        nodata = float(nodata)
    if nodata is not None and b0["type"] in ("Int64", "UInt64"):  # exact, JSON holds a double
        nodata = band1.GetNoDataValueAsInt64() if b0["type"] == "Int64" else band1.GetNoDataValueAsUInt64()
    point = info.get("metadata", {}).get("", {}).get("AREA_OR_POINT") == "Point"
    levels = [[ds.GetRasterBand(b + 1) for b in range(ds.RasterCount)]]
    for k in range(band1.GetOverviewCount()):
        levels.append([ds.GetRasterBand(b + 1).GetOverview(k) for b in range(ds.RasterCount)])
    stem = os.path.splitext(path)[0]
    with open(stem + ".txt", "w") as t:
        t.write("size %d %d\n" % tuple(info["size"]))
        t.write("bands %d\n" % len(info["bands"]))
        t.write("type %s\n" % b0["type"])
        t.write("block %d %d\n" % tuple(b0["block"]))
        t.write("nodata %s\n" % ("none" if nodata is None else repr(nodata)))
        t.write("geotransform %s\n" % ("none" if gt is None else " ".join("%.17g" % v for v in gt)))
        t.write("epsg %d\n" % epsg)
        t.write("point %d\n" % point)
        t.write("mask %d\n" % (band1.GetMaskFlags() == gdal.GMF_PER_DATASET))
        t.write("levels %d\n" % len(levels))
        for bands in levels:
            bw, bh = bands[0].GetBlockSize()
            t.write("level %d %d %d %d\n" % (bands[0].XSize, bands[0].YSize, bw, bh))
    with open(stem + ".blocks", "wb") as out:
        for bands in levels:
            bw, bh = bands[0].GetBlockSize()
            nx, ny = (bands[0].XSize + bw - 1) // bw, (bands[0].YSize + bh - 1) // bh
            for band in bands:
                for by, bx in itertools.product(range(ny), range(nx)):
                    present = band.GetMetadataItem("BLOCK_OFFSET_%d_%d" % (bx, by), "TIFF") is not None
                    out.write(b"\x01" if present else b"\x00")
                    out.write(struct.pack("<I", zlib.crc32(band.ReadBlock(bx, by))))


def main():
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    names, rejects, outsides = [], [], []
    i = 0
    # Byte order x bands x type x sparse; BigTIFF alternates so every type has both.
    for big_endian, bands, (gdt_name, code), sparse in itertools.product(
            (False, True), (1, 3), DTYPES, (False, True)):
        big = (i // 2 + big_endian) % 2 == 1
        options = ["TILED=YES", "BIGTIFF=" + ("YES" if big else "NO"),
                   "ENDIANNESS=" + ("BIG" if big_endian else "LITTLE")]
        if sparse:
            options.append("SPARSE_OK=TRUE")
        candidates = NODATA[gdt_name]
        name = "%s_%s_b%d_%s%s" % ("big" if big else "classic", "be" if big_endian else "le", bands,
                                   gdt_name, "_sparse" if sparse else "")
        path = os.path.join(outdir, name + ".tif")
        nodata = candidates[i % len(candidates)]
        # GDAL 3.13 does not return from BuildOverviews on a 64-bit integer band whose
        # nodata value is no exact double: those files get no overviews.
        inexact = isinstance(nodata, int) and int(float(nodata)) != nodata
        create(path, gdt_name, code, bands, options, sparse, nodata, GEO[i % len(GEO)],
               [2, 4] if i % 4 == 0 and not inexact else None, size=(W, H) if sparse else (W1, H1))
        dump(path)
        names.append(name)
        i += 1

    extra = [  # name, type, bands, options, sparse, nodata, geo, overviews, mask, size
        ("rgb", "Byte", 3, ["TILED=YES", "PHOTOMETRIC=RGB"], False, None, GEO[1], [2, 4], False, (700, 520)),
        ("overviews", "Float32", 1, ["TILED=YES"], False, -9999.0, GEO[2], [2, 4, 8], False, (700, 520)),
        ("overviews_sparse", "UInt16", 1, ["TILED=YES", "SPARSE_OK=TRUE"], True, 65535, GEO[4], [2, 4],
         False, (700, 520)),
        ("explicit_256", "Int16", 3, ["TILED=YES", "BLOCKXSIZE=256", "BLOCKYSIZE=256"], False, -9999, GEO[2],
         None, False, (W, H)),
        ("one_band_interleave_band", "Float64", 1, ["TILED=YES", "INTERLEAVE=BAND"], False, float("nan"),
         GEO[3], None, False, (W, H)),
        ("small", "Byte", 3, ["TILED=YES"], False, 0, GEO[1], None, False, (40, 37)),
        ("whole_tiles", "UInt16", 1, ["TILED=YES"], False, None, None, None, False, (512, 256)),
        ("all_absent", "Float32", 3, ["TILED=YES", "SPARSE_OK=TRUE"], None, 1.5, GEO[1], None, False, (W, H)),
        ("mask", "Byte", 3, ["TILED=YES"], False, None, GEO[1], [2], True, (W, H)),
    ]
    for name, gdt_name, bands, options, sparse, nodata, geo, overviews, mask, size in extra:
        path = os.path.join(outdir, name + ".tif")
        create(path, gdt_name, dict(DTYPES)[gdt_name], bands, options, sparse, nodata, geo, overviews, mask, size)
        dump(path)
        names.append(name)

    # Valid GeoTIFFs outside the reader's subset: refused at open, the message says why.
    outside = [  # name, bands, options, word of the message
        ("outside_strips", 1, [], "strips"),
        ("outside_strips_rgb", 3, ["BLOCKYSIZE=5"], "strips"),
        ("outside_tiles_512", 1, ["TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512"], "tiles"),
        ("outside_tiles_128", 3, ["TILED=YES", "BLOCKXSIZE=128", "BLOCKYSIZE=128"], "tiles"),
        ("outside_tiles_256x512", 1, ["TILED=YES", "BLOCKXSIZE=256", "BLOCKYSIZE=512"], "tiles"),
        ("outside_2_bands", 2, ["TILED=YES"], "bands"),
        ("outside_rgba", 4, ["TILED=YES"], "bands"),
        ("outside_band_interleaved", 3, ["TILED=YES", "INTERLEAVE=BAND"], "band-interleaved"),
    ]
    for name, bands, options, word in outside:
        create(os.path.join(outdir, name + ".tif"), "Byte", "B", bands, options, False, None, GEO[1], None)
        outsides.append("%s %s" % (name, word))

    creation = gdal.GetDriverByName("GTiff").GetMetadataItem("DMD_CREATIONOPTIONLIST")
    for codec, reported in (("DEFLATE", "DEFLATE"), ("LZW", "LZW"), ("PACKBITS", "PackBits"), ("ZSTD", "ZSTD"),
                            ("JPEG", "JPEG"), ("LZMA", "LZMA"), ("LERC", "LERC"), ("WEBP", "WebP")):
        if ">%s<" % codec not in creation:
            continue
        name = "reject_" + codec.lower()
        create(os.path.join(outdir, name + ".tif"), "Byte", "B", 3, ["COMPRESS=" + codec, "TILED=YES"],
               False, None, GEO[1], None)
        rejects.append("%s %s" % (name, reported))
    name = "reject_lzw_predictor"
    create(os.path.join(outdir, name + ".tif"), "UInt16", "H", 1, ["COMPRESS=LZW", "PREDICTOR=2"],
           False, None, None, None)
    rejects.append("%s LZW" % name)

    with open(os.path.join(outdir, "index.txt"), "w") as f:
        f.write("\n".join(names) + "\n")
    with open(os.path.join(outdir, "reject.txt"), "w") as f:
        f.write("\n".join(rejects) + "\n")
    with open(os.path.join(outdir, "outside.txt"), "w") as f:
        f.write("\n".join(outsides) + "\n")
    print("oracle: GDAL %s, %d files, %d rejects, %d outside the subset in %s"
          % (gdal.__version__, len(names), len(rejects), len(outsides), outdir))


if __name__ == "__main__":
    main()
