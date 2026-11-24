#!/usr/bin/env python3
"""Generate the GDAL oracle for geotiff.hpp.

    python3 oracle_generate.py OUTDIR

Writes GeoTIFFs with the system GDAL across layout x planar config x data type x byte
order x BigTIFF x sparse (+ nodata, georeferencing, overviews, masks), and next to each
<name>.tif

    <name>.txt     what gdalinfo reports (size, type, block, nodata, geotransform, EPSG)
    <name>.blocks  every block of every band of every level, read with GDAL's ReadBlock:
                   1 byte "present in the file" + the block bytes, level/band/row/column order

plus index.txt (one name per line) and reject.txt (compressed files: "<name> <codec>").
oracle_check (C++) reads all of it back through geotiff.hpp. Needs python-gdal only.
"""
import array
import itertools
import os
import sys

from osgeo import gdal, osr

gdal.UseExceptions()

W, H = 40, 37
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


def values(code, band, x0, y0, w, h):
    """Deterministic samples for a window, never all zero."""
    out = array.array(code)
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            v = 1 + x * 7 + y * 13 + band * 31
            if code == "B":
                out.append(v % 251 + 1)
            elif code == "b":
                out.append(v % 250 - 125 or 3)
            elif code == "H":
                out.append(v * 3 % 65000 + 1)
            elif code == "h":
                out.append(v * 3 % 60000 - 30000 or 3)
            elif code == "I":
                out.append(v * 70001)
            elif code == "i":
                out.append(v * 70001 - 50000000)
            elif code == "Q":
                out.append(v * 0x100000001 + 2 ** 63)
            elif code == "q":
                out.append(-v * 0x100000001)
            elif code == "f":
                out.append(v * 0.25 - 100.0)
            else:
                out.append(v * 0.125 - 1000.0 + 1e-9 * x)
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
            if sparse and (bx + 2 * by + b) % 3 == 0:
                continue  # never written: stays absent with SPARSE_OK=TRUE
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


def dump(path, split=False):
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
                    # Split mode (one strip shown row by row): GDAL has an offset for row 0 only.
                    key = "BLOCK_OFFSET_%d_%d" % (bx, 0 if split else by)
                    present = band.GetMetadataItem(key, "TIFF") is not None
                    out.write(b"\x01" if present else b"\x00")
                    out.write(band.ReadBlock(bx, by))


def main():
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    names, rejects = [], []
    i = 0
    for big, big_endian, tiled, planar, (gdt_name, code), sparse in itertools.product(
            (False, True), (False, True), (False, True), (0, 1, 2), DTYPES, (False, True)):
        bands = 1 if planar == 0 else 3
        options = ["BIGTIFF=" + ("YES" if big else "NO"), "ENDIANNESS=" + ("BIG" if big_endian else "LITTLE"),
                   "INTERLEAVE=" + ("BAND" if planar == 2 else "PIXEL")]
        options += ["TILED=YES", "BLOCKXSIZE=16", "BLOCKYSIZE=16"] if tiled else ["BLOCKYSIZE=5"]
        if sparse:
            options.append("SPARSE_OK=TRUE")
        candidates = NODATA[gdt_name]
        name = "%s_%s_%s_p%d_%s%s" % ("big" if big else "classic", "be" if big_endian else "le",
                                      "tiled" if tiled else "strips", planar, gdt_name,
                                      "_sparse" if sparse else "")
        path = os.path.join(outdir, name + ".tif")
        nodata = candidates[i % len(candidates)]
        # GDAL 3.13 does not return from BuildOverviews on a 64-bit integer band whose
        # nodata value is no exact double: those files get no overviews.
        inexact = isinstance(nodata, int) and int(float(nodata)) != nodata
        create(path, gdt_name, code, bands, options, sparse, nodata, GEO[i % len(GEO)],
               [2, 4] if i % 4 == 0 and not inexact else None)
        dump(path)
        names.append(name)
        i += 1

    extra = [  # name, type, bands, options, sparse, nodata, geo, overviews, mask, size
        ("default_strips", "Byte", 3, [], False, None, GEO[1], None, False, (W, H)),
        ("default_strips_sparse", "Int16", 1, ["SPARSE_OK=TRUE"], True, -9999, GEO[2], None, False, (W, H)),
        ("big_tiles", "Float32", 2, ["TILED=YES"], False, -9999.0, GEO[2], [2, 4, 8], False, (600, 500)),
        ("big_tiles_sparse", "UInt16", 1, ["TILED=YES", "BLOCKXSIZE=128", "BLOCKYSIZE=64", "SPARSE_OK=TRUE"],
         True, 65535, GEO[4], [2, 4], False, (600, 500)),
        ("mask", "Byte", 3, ["TILED=YES", "BLOCKXSIZE=16", "BLOCKYSIZE=16"], False, None, GEO[1], [2], True, (W, H)),
        ("mask_strips", "UInt16", 1, [], False, None, None, None, True, (W, H)),
        ("one_strip", "Float64", 1, ["BLOCKYSIZE=%d" % H], False, float("nan"), GEO[3], None, False, (W, H)),
    ]
    for name, gdt_name, bands, options, sparse, nodata, geo, overviews, mask, size in extra:
        path = os.path.join(outdir, name + ".tif")
        create(path, gdt_name, dict(DTYPES)[gdt_name], bands, options, sparse, nodata, geo, overviews, mask, size)
        dump(path)
        names.append(name)

    # One strip for the whole image: GDAL shows virtual strips of <= 8192 bytes (libtiff
    # strip chopping), or single rows for 8-bit images of more than 2000 rows (split).
    # (An absent strip in split mode is left out: GDAL fails to read it.)
    single = [  # name, type, bands, interleave, size, written, split
        ("chop_byte", "Byte", 1, "PIXEL", (300, 2500), True, False),
        ("chop_byte_absent", "Byte", 1, "PIXEL", (300, 2500), False, False),
        ("chop_rgb", "Byte", 3, "PIXEL", (300, 2500), True, False),
        ("chop_float64", "Float64", 2, "PIXEL", (40, 37), True, False),
        ("chop_wide_row", "UInt16", 1, "PIXEL", (5000, 3), True, False),
        ("chop_exact_8192", "Byte", 1, "PIXEL", (64, 128), True, False),
        ("chop_none_separate", "UInt16", 3, "BAND", (300, 2001), True, False),
        ("split_separate", "Byte", 3, "BAND", (300, 2001), True, True),
        ("split_int8", "Int8", 3, "BAND", (30, 2001), True, True),
        ("split_one_band_separate", "Byte", 1, "BAND", (300, 2001), True, True),
        ("split_narrow", "Byte", 3, "PIXEL", (1, 2001), True, True),
        ("split_not_2000", "Byte", 3, "BAND", (30, 2000), True, False),
    ]
    for name, gdt_name, bands, interleave, size, written, split in single:
        path = os.path.join(outdir, name + ".tif")
        gdt = gdal.GetDataTypeByName(gdt_name)
        ds = gdal.GetDriverByName("GTiff").Create(
            path, size[0], size[1], bands, gdt,
            options=["BLOCKYSIZE=%d" % size[1], "INTERLEAVE=" + interleave, "SPARSE_OK=TRUE"])
        for b in range(1, bands + 1):
            ds.GetRasterBand(b).SetNoDataValue(9)
            if written:
                ds.GetRasterBand(b).WriteRaster(0, 0, size[0], size[1],
                                                values(dict(DTYPES)[gdt_name], b, 0, 0, size[0], size[1]),
                                                buf_type=gdt)
        ds = None
        dump(path, split)
        names.append(name)

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
    print("oracle: GDAL %s, %d files, %d rejects in %s" % (gdal.__version__, len(names), len(rejects), outdir))


if __name__ == "__main__":
    main()
