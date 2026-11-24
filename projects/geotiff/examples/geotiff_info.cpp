// geotiff_info — print what geotiff.hpp sees in a GeoTIFF and read every block once.
//
//     geotiff_info FILE.tif
#include "geotiff/geotiff.hpp"

#include <cstdio>
#include <vector>

int main(int argc, char** argv) {
    if (argc != 2) {
        std::printf("usage: geotiff_info FILE.tif\n");
        return 2;
    }
    geotiff::Reader reader;
    const geotiff::Status status = reader.open(argv[1]);
    if (status != geotiff::Status::Ok) {
        std::printf("%s: %s\n", geotiff::statusName(status), reader.message());
        return 1;
    }

    std::printf("%s, %s-endian\n", reader.bigTiff() ? "BigTIFF" : "TIFF", reader.littleEndian() ? "little" : "big");
    const geotiff::GeoInfo& geo = reader.geo();
    if (geo.hasGeoTransform)
        std::printf("geotransform %.10g %.10g %.10g %.10g %.10g %.10g (%s)\n", geo.geoTransform[0],
                    geo.geoTransform[1], geo.geoTransform[2], geo.geoTransform[3], geo.geoTransform[4],
                    geo.geoTransform[5], geo.pixelIsPoint ? "point" : "area");
    if (geo.epsg != 0) std::printf("EPSG:%u\n", static_cast<unsigned>(geo.epsg));
    if (geo.hasNoData) std::printf("nodata %s\n", reader.noDataText());

    std::vector<unsigned char> block;
    for (std::size_t i = 0; i < reader.imageCount(); ++i) {
        const geotiff::ImageInfo& image = reader.image(i);
        std::printf("image %u: %ux%u, %u band(s) %s, %s %ux%u%s%s", static_cast<unsigned>(i), image.width,
                    image.height, image.bands, geotiff::dataTypeName(image.dataType),
                    image.tiled ? "tiles" : "strips", image.blockWidth, image.blockHeight,
                    image.overview ? ", overview" : "", image.mask ? ", mask" : "");
        if (image.status != geotiff::Status::Ok) {
            std::printf(" — not readable: %s\n", reader.imageMessage(i));
            continue;
        }
        block.resize(static_cast<std::size_t>(image.blockBytes));
        unsigned long read = 0, sparse = 0;
        for (unsigned band = 0; band < image.bands; ++band)
            for (std::uint32_t by = 0; by < image.blocksY; ++by)
                for (std::uint32_t bx = 0; bx < image.blocksX; ++bx) {
                    const geotiff::Status s = reader.readBlock(i, bx, by, band, block.data(), block.size());
                    if (!geotiff::ok(s)) {
                        std::printf("\n%s: %s\n", geotiff::statusName(s), reader.message());
                        return 1;
                    }
                    ++(s == geotiff::Status::Sparse ? sparse : read);
                }
        std::printf(" — %lu blocks read, %lu sparse\n", read, sparse);
    }
    return 0;
}
