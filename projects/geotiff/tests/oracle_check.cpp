// oracle_check.cpp — compare the geotiff library with GDAL, file by file.
//
//     oracle_check DIR
//
// DIR is written by oracle_generate.py: for every name in index.txt the CRC-32 of every
// block of the main image as GDAL's ReadBlock gives it (<name>.blocks) must equal the
// CRC-32 of what Reader::readBlock gives, absent blocks must be reported as sparse, and
// size / type / block size / nodata / geotransform / EPSG must equal what gdalinfo
// reported (<name>.txt). Files in reject.txt are compressed and must be refused at open
// with the codec named; files in outside.txt lie outside the project constraints (strips,
// other tile sizes, band counts, band-interleaved, big-endian, other data types) and must
// be refused with the reason named.
#include "geotiff/geotiff.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static long g_checks = 0, g_failed = 0;
static std::string g_name;

// CRC-32 as zlib computes it (polynomial 0xEDB88320).
static std::uint32_t crc32(const unsigned char* data, std::size_t size) {
    static std::uint32_t table[256];
    if (table[1] == 0)
        for (std::uint32_t i = 0; i < 256; ++i) {
            std::uint32_t c = i;
            for (int k = 0; k < 8; ++k) c = (c & 1u) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
            table[i] = c;
        }
    std::uint32_t crc = 0xFFFFFFFFu;
    for (std::size_t i = 0; i < size; ++i) crc = table[(crc ^ data[i]) & 0xFFu] ^ (crc >> 8);
    return crc ^ 0xFFFFFFFFu;
}

static bool check(bool cond, const char* what) {
    ++g_checks;
    if (!cond && ++g_failed <= 40) std::printf("FAIL %s: %s\n", g_name.c_str(), what);
    return cond;
}

struct Expected {
    unsigned w = 0, h = 0, bands = 0, bw = 0, bh = 0;
    std::string type, nodata = "none";
    bool hasGt = false, point = false;
    double gt[6] = {0, 0, 0, 0, 0, 0};
    unsigned epsg = 0;
};

static bool readExpected(const std::string& path, Expected& e) {
    std::ifstream in(path);
    if (!in) return false;
    std::string line;
    while (std::getline(in, line)) {
        std::istringstream s(line);
        std::string key;
        s >> key;
        if (key == "size") s >> e.w >> e.h;
        else if (key == "bands") s >> e.bands;
        else if (key == "type") s >> e.type;
        else if (key == "block") s >> e.bw >> e.bh;
        else if (key == "nodata") s >> e.nodata;
        else if (key == "epsg") s >> e.epsg;
        else if (key == "point") s >> e.point;
        else if (key == "geotransform") {
            std::string v;
            for (int i = 0; i < 6 && (s >> v) && v != "none"; ++i) {
                e.gt[i] = std::strtod(v.c_str(), nullptr);
                e.hasGt = i == 5;
            }
        }
    }
    return e.w != 0;
}

static void checkFile(const std::string& dir, const std::string& name) {
    g_name = name;
    Expected e;
    if (!check(readExpected(dir + "/" + name + ".txt", e), "read the .txt of the oracle")) return;
    geotiff::Reader r;
    const geotiff::Status s = r.open((dir + "/" + name + ".tif").c_str());
    if (!check(s == geotiff::Status::Ok, "open")) {
        std::printf("  %s: %s\n", geotiff::statusName(s), r.message());
        return;
    }

    // Metadata as gdalinfo reports it.
    const geotiff::ImageInfo& main = r.image();
    check(main.width == e.w && main.height == e.h, "image size");
    check(main.bands == e.bands, "band count");
    check(e.type == geotiff::dataTypeName(main.dataType), "data type");
    check(e.bw == geotiff::kTileSize && e.bh == geotiff::kTileSize, "block size");
    check(main.blockBytes == geotiff::kTileSamples * geotiff::dataTypeSize(main.dataType), "block bytes");
    const geotiff::GeoInfo& g = r.geo();
    check(g.hasNoData == (e.nodata != "none"), "nodata presence");
    if (g.hasNoData && e.nodata != "none") {
        const double want = std::strtod(e.nodata.c_str(), nullptr);
        check((want != want && g.noData != g.noData) || want == g.noData, "nodata value");
    }
    check(g.hasGeoTransform == e.hasGt, "geotransform presence");
    for (int i = 0; i < 6 && e.hasGt && g.hasGeoTransform; ++i)
        check(std::fabs(g.geoTransform[i] - e.gt[i]) <= 1e-12 * (1.0 + std::fabs(e.gt[i])), "geotransform value");
    check(g.epsg == e.epsg, "EPSG code");
    check(g.pixelIsPoint == e.point, "AREA_OR_POINT");

    // Every block of every band against GDAL's ReadBlock.
    std::FILE* dump = std::fopen((dir + "/" + name + ".blocks").c_str(), "rb");
    if (!check(dump != nullptr, "open the .blocks of the oracle")) return;
    std::vector<unsigned char> got(main.blockBytes);
    long blocks = 0, mismatches = 0;
    for (unsigned band = 0; band < main.bands; ++band)
        for (unsigned by = 0; by < main.blocksY; ++by)
            for (unsigned bx = 0; bx < main.blocksX; ++bx, ++blocks) {
                const int present = std::fgetc(dump);
                unsigned char c[4];
                if (present == EOF || std::fread(c, 1, 4, dump) != 4) {
                    check(false, "block dump is cut short");
                    std::fclose(dump);
                    return;
                }
                const std::uint32_t want = c[0] | c[1] << 8 | c[2] << 16 | static_cast<std::uint32_t>(c[3]) << 24;
                std::memset(got.data(), 0xA5, got.size());
                const geotiff::Status rs = r.readBlock(bx, by, band, got.data(), got.size());
                const bool equal = crc32(got.data(), got.size()) == want;
                const bool same = rs == (present ? geotiff::Status::Ok : geotiff::Status::Sparse) &&
                                  r.blockPresent(bx, by) == (present != 0) && equal;
                if (!same && ++mismatches <= 3)
                    std::printf("  band %u block (%u, %u): status %s, present in GDAL %d, bytes %s\n", band, bx, by,
                                geotiff::statusName(rs), present, equal ? "equal" : "differ");
            }
    check(mismatches == 0, "all blocks equal GDAL's ReadBlock");
    check(blocks > 0 && std::fgetc(dump) == EOF, "block dump fully consumed");
    std::fclose(dump);
}

int main(int argc, char** argv) {
    if (argc != 2) {
        std::printf("usage: oracle_check DIR\n");
        return 2;
    }
    const std::string dir = argv[1];
    std::ifstream index(dir + "/index.txt");
    std::string name;
    long files = 0, rejects = 0, outsides = 0;
    while (std::getline(index, name))
        if (!name.empty()) {
            checkFile(dir, name);
            ++files;
        }
    std::ifstream reject(dir + "/reject.txt");
    std::string codec;
    while (reject >> name >> codec) {
        g_name = name;
        geotiff::Reader r;
        check(r.open((dir + "/" + name + ".tif").c_str()) == geotiff::Status::Unsupported, "compressed file refused");
        check(std::strstr(r.message(), codec.c_str()) != nullptr, "message names the codec");
        check(!r.isOpen(), "reader stays closed");
        ++rejects;
    }
    std::ifstream outside(dir + "/outside.txt");
    std::string word;
    while (outside >> name >> word) {
        g_name = name;
        geotiff::Reader r;
        check(r.open((dir + "/" + name + ".tif").c_str()) == geotiff::Status::Unsupported, "file outside the subset refused");
        if (!check(std::strstr(r.message(), word.c_str()) != nullptr, "message names the reason"))
            std::printf("  message: %s\n", r.message());
        check(!r.isOpen(), "reader stays closed");
        ++outsides;
    }
    g_name = "index";
    check(files > 0 && rejects > 0 && outsides > 0, "oracle directory holds files");
    std::printf("oracle_check: %ld files, %ld rejects, %ld outside the subset, %ld checks, %ld failed\n", files,
                rejects, outsides, g_checks, g_failed);
    return g_failed == 0 ? 0 : 1;
}
