#!/usr/bin/env python3
"""Generate the GDAL oracle for geotiff.hpp.

    python3 oracle_generate.py OUTDIR

Writes GeoTIFFs with the system GDAL inside the reader's subset (little-endian, 256x256
tiles, 1 band or 3 pixel-interleaved bands, Byte / UInt16 / Int16) across data type x
BigTIFF x sparse (+ nodata, georeferencing; some with overviews and a mask, which the
reader must ignore), and next to each <name>.tif

    <name>.txt     what gdalinfo reports (size, type, block, nodata, geotransform, EPSG)
    <name>.blocks  every block of every band of the main image, read with GDAL's
                   ReadBlock: 1 byte "present in the file" + the CRC-32 of the block bytes
                   (4 bytes, little endian), band/row/column order

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
DTYPES = [("Byte", "B"), ("UInt16", "H"), ("Int16", "h")]  # GDAL name, array typecode
NODATA = {  # candidates per type; None = no nodata value
    "Byte": [None, 255, 0, 7], "UInt16": [None, 65535, 9999], "Int16": [None, -9999, -32768],
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
    "H": lambda v, x: v * 3 % 65000 + 1,
    "h": lambda v, x: v * 3 % 60000 - 30000 or 3,
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
    point = info.get("metadata", {}).get("", {}).get("AREA_OR_POINT") == "Point"
    bands = [ds.GetRasterBand(b + 1) for b in range(ds.RasterCount)]
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
    with open(stem + ".blocks", "wb") as out:
        bw, bh = band1.GetBlockSize()
        nx, ny = (ds.RasterXSize + bw - 1) // bw, (ds.RasterYSize + bh - 1) // bh
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
    # BigTIFF x bands x type x sparse; every fourth file has overviews (ignored by the reader).
    for big, bands, (gdt_name, code), sparse in itertools.product(
            (False, True), (1, 3), DTYPES, (False, True)):
        options = ["TILED=YES", "BIGTIFF=" + ("YES" if big else "NO")]
        if sparse:
            options.append("SPARSE_OK=TRUE")
        candidates = NODATA[gdt_name]
        name = "%s_b%d_%s%s" % ("big" if big else "classic", bands, gdt_name, "_sparse" if sparse else "")
        path = os.path.join(outdir, name + ".tif")
        create(path, gdt_name, code, bands, options, sparse, candidates[i % len(candidates)],
               GEO[i % len(GEO)], [2, 4] if i % 4 == 0 else None, size=(W, H) if sparse else (W1, H1))
        dump(path)
        names.append(name)
        i += 1

    extra = [  # name, type, bands, options, sparse, nodata, geo, overviews, mask, size
        ("rgb", "Byte", 3, ["TILED=YES", "PHOTOMETRIC=RGB"], False, None, GEO[1], [2, 4], False, (700, 520)),
        ("overviews", "Int16", 1, ["TILED=YES"], False, -9999, GEO[2], [2, 4, 8], False, (700, 520)),
        ("overviews_sparse", "UInt16", 1, ["TILED=YES", "SPARSE_OK=TRUE"], True, 65535, GEO[4], [2, 4],
         False, (700, 520)),
        ("explicit_256", "Int16", 3, ["TILED=YES", "BLOCKXSIZE=256", "BLOCKYSIZE=256"], False, -9999, GEO[2],
         None, False, (W, H)),
        ("one_band_interleave_band", "UInt16", 1, ["TILED=YES", "INTERLEAVE=BAND"], False, 9999,
         GEO[3], None, False, (W, H)),
        ("small", "Byte", 3, ["TILED=YES"], False, 0, GEO[1], None, False, (40, 37)),
        ("whole_tiles", "UInt16", 1, ["TILED=YES"], False, None, None, None, False, (512, 256)),
        ("all_absent", "Int16", 3, ["TILED=YES", "SPARSE_OK=TRUE"], None, -9999, GEO[1], None, False, (W, H)),
        ("mask", "Byte", 3, ["TILED=YES"], False, None, GEO[1], [2], True, (W, H)),
    ]
    for name, gdt_name, bands, options, sparse, nodata, geo, overviews, mask, size in extra:
        path = os.path.join(outdir, name + ".tif")
        create(path, gdt_name, dict(DTYPES)[gdt_name], bands, options, sparse, nodata, geo, overviews, mask, size)
        dump(path)
        names.append(name)

    # Valid GeoTIFFs outside the reader's subset: refused at open, the message says why.
    outside = [  # name, type, bands, options, word of the message
        ("outside_strips", "Byte", 1, [], "strips"),
        ("outside_strips_rgb", "Byte", 3, ["BLOCKYSIZE=5"], "strips"),
        ("outside_tiles_512", "Byte", 1, ["TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512"], "tiles"),
        ("outside_tiles_128", "Byte", 3, ["TILED=YES", "BLOCKXSIZE=128", "BLOCKYSIZE=128"], "tiles"),
        ("outside_tiles_256x512", "Byte", 1, ["TILED=YES", "BLOCKXSIZE=256", "BLOCKYSIZE=512"], "tiles"),
        ("outside_2_bands", "Byte", 2, ["TILED=YES"], "bands"),
        ("outside_rgba", "Byte", 4, ["TILED=YES"], "bands"),
        ("outside_band_interleaved", "Byte", 3, ["TILED=YES", "INTERLEAVE=BAND"], "band-interleaved"),
        ("outside_big_endian", "UInt16", 1, ["TILED=YES", "ENDIANNESS=BIG"], "big-endian"),
        ("outside_big_endian_bigtiff", "Byte", 3, ["TILED=YES", "ENDIANNESS=BIG", "BIGTIFF=YES"], "big-endian"),
        ("outside_int8", "Int8", 1, ["TILED=YES"], "samples"),
        ("outside_uint32", "UInt32", 1, ["TILED=YES"], "samples"),
        ("outside_int32", "Int32", 3, ["TILED=YES"], "samples"),
        ("outside_float32", "Float32", 1, ["TILED=YES"], "samples"),
        ("outside_float64", "Float64", 1, ["TILED=YES"], "samples"),
    ]
    codes = {"Byte": "B", "Int8": "b", "UInt16": "H", "UInt32": "I", "Int32": "i", "Float32": "f", "Float64": "d"}
    for name, gdt_name, bands, options, word in outside:
        # sparse=None: nothing is written, the reader refuses the file by its tags alone
        create(os.path.join(outdir, name + ".tif"), gdt_name, codes[gdt_name], bands, options, None, None,
               GEO[1], None)
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
