// oracle_check.cpp — compare geotiff.hpp with GDAL, file by file.
//
//     oracle_check DIR
//
// DIR is written by oracle_generate.py: for every name in index.txt the block dump of
// GDAL's ReadBlock (<name>.blocks) must equal Reader::readBlock byte for byte, absent
// blocks must be reported as sparse, and size / type / block size / nodata / geotransform
// / EPSG must equal what gdalinfo reported (<name>.txt). Files in reject.txt are
// compressed and must be refused at open with the codec named.
#include "geotiff/geotiff.hpp"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static long g_checks = 0, g_failed = 0;
static std::string g_name;

static bool check(bool cond, const char* what) {
    ++g_checks;
    if (!cond && ++g_failed <= 40) std::printf("FAIL %s: %s\n", g_name.c_str(), what);
    return cond;
}

struct Level { unsigned w = 0, h = 0, bw = 0, bh = 0; };
struct Expected {
    unsigned w = 0, h = 0, bands = 0, bw = 0, bh = 0;
    std::string type, nodata = "none";
    bool hasGt = false, point = false, mask = false;
    double gt[6] = {0, 0, 0, 0, 0, 0};
    unsigned epsg = 0;
    std::vector<Level> levels;
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
        else if (key == "mask") s >> e.mask;
        else if (key == "geotransform") {
            std::string v;
            for (int i = 0; i < 6 && (s >> v) && v != "none"; ++i) {
                e.gt[i] = std::strtod(v.c_str(), nullptr);
                e.hasGt = i == 5;
            }
        } else if (key == "level") {
            Level l;
            s >> l.w >> l.h >> l.bw >> l.bh;
            e.levels.push_back(l);
        }
    }
    return !e.levels.empty();
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
    const geotiff::ImageInfo& main = r.image(0);
    check(main.width == e.w && main.height == e.h, "image size");
    check(main.bands == e.bands, "band count");
    check(e.type == geotiff::dataTypeName(main.dataType), "data type");
    check(main.blockWidth == e.bw && main.blockHeight == e.bh, "block size");
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
    check(r.overviewCount() + 1 == e.levels.size(), "overview count");
    bool haveMask = false;
    for (std::size_t i = 0; i < r.imageCount(); ++i) haveMask = haveMask || r.image(i).mask;
    check(haveMask == e.mask, "mask listed");

    // Every block of every band of every level against GDAL's ReadBlock.
    std::FILE* dump = std::fopen((dir + "/" + name + ".blocks").c_str(), "rb");
    if (!check(dump != nullptr, "open the .blocks of the oracle")) return;
    std::vector<unsigned char> want, got;
    long blocks = 0, mismatches = 0;
    for (std::size_t level = 0; level < e.levels.size() && level <= r.overviewCount(); ++level) {
        const std::size_t image = level == 0 ? 0 : r.overviewImage(level - 1);
        const geotiff::ImageInfo& in = r.image(image);
        const Level& l = e.levels[level];
        if (!check(in.status == geotiff::Status::Ok, "level readable")) break;
        if (!check(in.width == l.w && in.height == l.h && in.blockWidth == l.bw && in.blockHeight == l.bh,
                   "level size and block size"))
            break;
        want.resize(static_cast<std::size_t>(in.blockBytes));
        got.resize(want.size());
        for (unsigned band = 0; band < in.bands; ++band)
            for (unsigned by = 0; by < in.blocksY; ++by)
                for (unsigned bx = 0; bx < in.blocksX; ++bx, ++blocks) {
                    const int present = std::fgetc(dump);
                    if (present == EOF || std::fread(want.data(), 1, want.size(), dump) != want.size()) {
                        check(false, "block dump is cut short");
                        std::fclose(dump);
                        return;
                    }
                    std::memset(got.data(), 0xA5, got.size());
                    const geotiff::Status rs = r.readBlock(image, bx, by, band, got.data(), got.size());
                    const bool same = rs == (present ? geotiff::Status::Ok : geotiff::Status::Sparse) &&
                                      r.blockPresent(image, bx, by, band) == (present != 0) && got == want;
                    if (!same && ++mismatches <= 3)
                        std::printf("  level %u band %u block (%u, %u): status %s, present in GDAL %d, bytes %s\n",
                                    static_cast<unsigned>(level), band, bx, by, geotiff::statusName(rs), present,
                                    got == want ? "equal" : "differ");
                }
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
    long files = 0, rejects = 0;
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
    g_name = "index";
    check(files > 0 && rejects > 0, "oracle directory holds files");
    std::printf("oracle_check: %ld files, %ld rejects, %ld checks, %ld failed\n", files, rejects, g_checks, g_failed);
    return g_failed == 0 ? 0 : 1;
}
