// cbor_test.cpp -- test suite for cbor.hpp (C++ twin of cbor_test.m).
//
// Build and run (any C++17 compiler, no dependencies):
//   g++ -std=c++17 -Wall -Wextra -pedantic -O1 -o /tmp/cbor_test cbor_test.cpp && /tmp/cbor_test
//
// Covers the same groups as cbor_test.m: RFC 8949 Appendix A vectors, float16
// edge cases, RFC 8746 typed arrays (exact bytes, both byte orders, all
// element types, multi-dim tags 40/1040), generic-decoder features (indefinite
// lengths, chunked strings, >2^53 integers, simple values, unknown tags,
// non-text map keys), malformed-input errors, round trips, the Writer
// streaming API, and a header+blocks logger sequence.
//
// Extra modes for the cbor2 interop check (see cbor_interop_check.py):
//   cbor_test --write FILE   write a logger stream (header + 3 typed blocks)
//   cbor_test --read FILE    decode a CBOR sequence, print diagnostic notation

#include "cbor.hpp"

#include <cstdio>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

using cbor::Value;
using Bytes = std::vector<uint8_t>;

static int n_pass = 0, n_fail = 0;
static std::vector<std::string> failures;

static void ok(bool cond, const std::string& label) {
    if (cond) { ++n_pass; return; }
    ++n_fail;
    failures.push_back(label);
    std::fprintf(stderr, "  FAIL: %s\n", label.c_str());
}

static Bytes hx(const std::string& h) {
    Bytes b;
    for (size_t i = 0; i + 1 < h.size(); i += 2)
        b.push_back(static_cast<uint8_t>(std::stoul(h.substr(i, 2), nullptr, 16)));
    return b;
}

static std::string hexs(const Bytes& b) {
    static const char* d = "0123456789abcdef";
    std::string s;
    for (uint8_t x : b) { s += d[x >> 4]; s += d[x & 15]; }
    return s;
}

// encode -> exact bytes
static void chk(const Value& v, const std::string& hex) {
    Bytes got = cbor::encode(v);
    ok(got == hx(hex), "enc " + hex + " (got " + hexs(got) + ")");
}
// decode bytes -> exact value
static void dchk(const std::string& hex, const Value& want) {
    Value got = cbor::decode(hx(hex));
    ok(got == want, "dec " + hex + " (got " + cbor::diag(got) + ", want " + cbor::diag(want) + ")");
}
// round trip
static void rt(const Value& v, const std::string& label) {
    Value back = cbor::decode(cbor::encode(v));
    ok(back == v, "roundtrip " + label + " (got " + cbor::diag(back) + ")");
}
// decode must throw cbor::error with id
static void echk(const std::string& hex, const std::string& id) {
    try {
        Value v = cbor::decode(hx(hex));
        ok(false, "no error for " + hex + " (got " + cbor::diag(v) + ")");
    } catch (const cbor::error& e) {
        ok(e.id == id, hex + " -> " + id + " (got " + e.id + ")");
    }
}

template <class T>
static Value tv(std::initializer_list<T> xs) { return Value(std::vector<T>(xs)); }

static Bytes logger_stream() {
    Value hdr = Value::map({{"v", uint8_t(1)}, {"dev", "imu0"}, {"t0", uint32_t(1756944000)},
                            {"dt_ms", uint16_t(10)}, {"fields", Value::array({"t", "ax"})}});
    cbor::Writer w;
    w.value(Value::tagged(55799, hdr));
    const int B = 4;
    for (int blk = 0; blk < 3; ++blk) {
        std::vector<uint32_t> t(B);
        std::vector<float> ax(B);
        for (int k = 0; k < B; ++k) {
            t[k] = static_cast<uint32_t>((blk * B + k) * 10);
            ax[k] = static_cast<float>(t[k]) * 0.1f;
        }
        w.array(2).typed(t).typed(ax);
    }
    return w.buf;
}

static int run_tests() {
    // ---- 1. RFC 8949 Appendix A: integers ---------------------------------
    std::puts("integers ...");
    chk(0, "00"); chk(1, "01"); chk(10, "0a"); chk(23, "17"); chk(24, "1818");
    chk(25, "1819"); chk(100, "1864"); chk(1000, "1903e8"); chk(1000000, "1a000f4240");
    chk(uint64_t(1000000000000ULL), "1b000000e8d4a51000");
    chk(uint64_t(18446744073709551615ULL), "1bffffffffffffffff");
    chk(uint64_t(9007199254740993ULL), "1b0020000000000001");
    chk(-1, "20"); chk(-10, "29"); chk(-100, "3863"); chk(-1000, "3903e7");
    chk(INT64_MIN, "3b7fffffffffffffff");
    chk(int8_t(-1), "20"); chk(uint16_t(1000), "1903e8");
    dchk("00", 0); dchk("1903e8", 1000); dchk("3903e7", -1000);
    dchk("1bffffffffffffffff", uint64_t(18446744073709551615ULL));
    dchk("3b7fffffffffffffff", INT64_MIN);
    ok(cbor::decode(hx("1bffffffffffffffff")).as_uint64() == UINT64_MAX, "uint64 max as_uint64");
    ok(cbor::decode(hx("1bffffffffffffffff")).is_int(), "uint64 max is_int");
    rt(uint64_t(1) << 60, "uint64 2^60"); rt(-(int64_t(1) << 60), "int64 -2^60");
    echk("3bffffffffffffffff", "range");                   // -2^64: below int64

    // ---- 2. floats --------------------------------------------------------
    std::puts("floats ...");
    chk(1.1, "fb3ff199999999999a");
    chk(100000.0f, "fa47c35000");
    chk(3.4028234663852886e38f, "fa7f7fffff");
    chk(1.0e300, "fb7e37e43c8800759c");
    chk(-4.1, "fbc010666666666666");
    chk(double(INFINITY), "fb7ff0000000000000"); chk(float(INFINITY), "fa7f800000");
    dchk("fa7f800000", float(INFINITY));
    ok(std::isnan(cbor::decode(hx("fb7ff8000000000000")).as_double()), "dec NaN");
    chk(float(NAN), "fa7fc00000"); chk(double(NAN), "fb7ff8000000000000");
    chk(-float(NAN), "fa7fc00000");                         // sign bit must not leak
    rt(9.81f, "float scalar"); rt(3.141592653589793, "double scalar");
    ok(cbor::decode(hx("fa47c35000")).float_width() == 4, "float32 width recorded");
    ok(cbor::decode(hx("fa47c35000")) != Value(100000.0), "f32 != f64 (width part of identity)");

    // ---- 3. float16 -------------------------------------------------------
    std::puts("float16 ...");
    auto f16 = [](double x) { return Value(cbor::f16(x)); };
    chk(f16(0.0), "f90000"); chk(f16(-0.0), "f98000");
    chk(f16(1.0), "f93c00"); chk(f16(1.5), "f93e00");
    chk(f16(65504), "f97bff"); chk(f16(65520), "f97c00");    // ties-to-even -> Inf
    chk(f16(std::ldexp(1.0, -24)), "f90001"); chk(f16(1.5 * std::ldexp(1.0, -24)), "f90002");
    chk(f16(std::ldexp(1.0, -25)), "f90000");                // tie rounds to even (0)
    chk(f16(std::ldexp(1.0, -25) * 1.01), "f90001");         // just above the tie -> 1 ulp
    chk(f16(std::ldexp(1.0, -14)), "f90400");                // smallest normal
    chk(f16(-4), "f9c400");
    chk(f16(INFINITY), "f97c00"); chk(f16(-INFINITY), "f9fc00"); chk(f16(NAN), "f97e00");
    chk(f16(1.0 + std::ldexp(1.0, -11)), "f93c00");          // tie at 1 + 2^-11 -> even
    chk(f16(1.0 + 3 * std::ldexp(1.0, -11)), "f93c02");      // tie -> even (up)
    dchk("f90001", f16(std::ldexp(1.0, -24))); dchk("f90400", f16(std::ldexp(1.0, -14)));
    dchk("f93e00", f16(1.5)); dchk("f9c400", f16(-4)); dchk("f97c00", f16(INFINITY));
    ok(std::isnan(cbor::decode(hx("f97e00")).as_double()), "dec f16 NaN");
    rt(f16(0.333251953125), "f16 round trip");

    // ---- 4. strings -------------------------------------------------------
    std::puts("strings ...");
    chk("", "60"); chk("a", "6161"); chk("IETF", "6449455446"); chk("\"\\", "62225c");
    chk(std::string("\xc3\xbc"), "62c3bc");                  // "ü" as UTF-8
    chk(hx("01020304"), "4401020304");                       // byte string
    rt("grüße", "utf8 text"); rt(Bytes{1, 2, 3}, "byte string");
    dchk("7f657374726561646d696e67ff", "streaming");         // indefinite text
    dchk("5f42010243030405ff", Bytes{1, 2, 3, 4, 5});         // indefinite bytes
    chk(Bytes{}, "40");                                      // empty bytes stay bytes (unlike MATLAB)
    chk(std::string_view("hi"), "626869");

    // ---- 5. arrays and maps ----------------------------------------------
    std::puts("arrays/maps ...");
    chk(Value::array({}), "80");
    chk(Value::array({1, 2, 3}), "83010203");
    chk(Value::array({1, Value::array({2, 3}), Value::array({4, 5})}), "8301820203820405");
    {
        Value::Array a;
        for (int i = 1; i <= 25; ++i) a.push_back(i);
        chk(Value(a), "98190102030405060708090a0b0c0d0e0f101112131415161718181819");
    }
    chk(Value::map({{"a", 1}, {"b", Value::array({2, 3})}}), "a26161016162820203");
    chk(Value::map({{"a", 1}, {"b", "c"}}), "a261610161626163");
    dchk("9f0102ff", Value::array({1, 2}));                  // indefinite array
    {
        Value m = cbor::decode(hx("bf61610161629f0203ffff"));   // indefinite map + array
        ok(m.is_map() && m["a"] == 1 && m["b"] == Value::array({2, 3}), "dec indefinite map");
        Value k = cbor::decode(hx("a16361206201"));              // key "a b"
        ok(k["a b"] == 1, "space in key");
        Value nk = cbor::decode(hx("a1016178"));                 // numeric key
        ok(nk.is_map() && nk.as_map()[0].first == 1 && nk.as_map()[0].second == "x", "numeric key");
        ok(nk.find("nope") == nullptr && !nk.contains("nope"), "find missing key");
        try { (void)nk["nope"]; ok(false, "missing key throws"); }
        catch (const cbor::error& e) { ok(e.id == "range", "missing key throws range"); }
    }
    rt(Value::map({{"v", 1}, {"name", "imu0"}, {"x", 1.5f}}), "flat map");
    rt(Value::array({1, "two", 3.0f, Value::array({nullptr})}), "mixed array");
    rt(Value::array({true, false}), "bool array");
    {
        Value m = Value::map({});
        m.set("a", 1).set("b", 2).set("a", 3);
        ok(m.size() == 2 && m["a"] == 3, "set replaces existing key");
        Value a = Value::array({});
        a.push(1).push("x");
        ok(a.size() == 2 && a[1] == "x", "push");
        ok(cbor::diag(m) == "{\"a\": 3, \"b\": 2}", "diag map: " + cbor::diag(m));
    }
    // map key order is preserved, not sorted
    chk(Value::map({{"b", 1}, {"a", 2}}), "a2616201616102");

    // ---- 6. simple values, null, undefined --------------------------------
    std::puts("simple values ...");
    chk(true, "f5"); chk(false, "f4"); chk(nullptr, "f6"); chk(Value::undefined(), "f7");
    dchk("f5", true); dchk("f6", nullptr); dchk("f7", Value::undefined());
    dchk("f0", Value::simple(16)); dchk("f8ff", Value::simple(255));
    chk(Value::simple(16), "f0"); chk(Value::simple(255), "f8ff");
    echk("f818", "reserved");                                // two-byte simple < 32
    try { Value::simple(24); ok(false, "simple(24) throws"); }
    catch (const cbor::error& e) { ok(e.id == "reserved", "simple(24) reserved"); }

    // ---- 7. tags ----------------------------------------------------------
    std::puts("tags ...");
    chk(Value::tagged(0, "2013-03-21T20:04:00Z"), "c074323031332d30332d32315432303a30343a30305a");
    chk(Value::tagged(1, uint32_t(1363896240)), "c11a514b67b0");
    {
        Value t = cbor::decode(hx("c249010000000000000000"));   // tag 2 bignum: unknown
        ok(t.is_tagged() && t.tag() == 2 && t.content().is_bytes() && t.content().size() == 9,
           "unknown tag passthrough");
    }
    rt(Value::tagged(1234, Value::array({1, "x"})), "tagged array");
    dchk("d9d9f763616263", "abc");                            // 55799 unwraps
    echk("df", "reserved");                                   // indefinite tag
    echk("c0", "eof");                                        // tag without content

    // ---- 8. typed arrays (RFC 8746) ---------------------------------------
    std::puts("typed arrays ...");
    chk(tv<uint32_t>({1, 2}), "d846480100000002000000");
    chk(tv<float>({1.5f, 2.5f}), "d855480000c03f00002040");
    rt(tv<uint16_t>({0, 65535}), "u16 vec"); rt(tv<uint32_t>({1, 2, 3}), "u32 vec");
    rt(tv<uint64_t>({0, UINT64_MAX}), "u64 vec");
    rt(tv<int8_t>({-128, 127}), "i8 vec"); rt(tv<int16_t>({-1, 2}), "i16 vec");
    rt(tv<int32_t>({INT32_MIN, 0}), "i32 vec");
    rt(tv<int64_t>({INT64_MIN, INT64_MAX}), "i64 vec");
    rt(tv<float>({9.81f, 0.f, -1.5f, float(NAN)}), "f32 vec (with NaN)");
    rt(tv<double>({1 / 3.0, 2 / 3.0, 1.0}), "f64 vec");
    rt(Value::typed<uint8_t>(Bytes{1, 2, 3}), "explicit u8 typed (tag 64)");
    chk(Value::typed<uint8_t>(Bytes{1, 2}), "d840420102");
    dchk("d8414400010002", tv<uint16_t>({1, 2}));             // uint16 BE
    dchk("d842480000000100000002", tv<uint32_t>({1, 2}));     // uint32 BE
    dchk("d851483fc0000040200000", tv<float>({1.5f, 2.5f}));  // float32 BE
    dchk("d85444003c003e", tv<double>({1.0, 1.5}));           // float16 BE -> f64
    dchk("d854440000003e", tv<double>({0.0, 1.5}));           // float16 LE -> f64
    dchk("d844420102", Value::typed<uint8_t>(Bytes{1, 2}));   // clamped u8 -> u8
    {
        Value v = cbor::decode(hx("d846480100000002000000"));
        ok(v.is_typed() && v.elem() == cbor::Elem::u32 && v.count() == 2, "typed meta");
        ok(v.typed<uint32_t>() == std::vector<uint32_t>({1, 2}), "typed<u32>");
        ok(v.data<uint32_t>()[1] == 2, "data<u32> view");
        ok(v.to_doubles() == std::vector<double>({1.0, 2.0}), "to_doubles");
        try { (void)v.typed<int32_t>(); ok(false, "typed<i32> on u32 throws"); }
        catch (const cbor::error& e) { ok(e.id == "type", "typed<T> mismatch -> type"); }
        Value f128 = cbor::decode(hx("d857500000000000000000000000000000000000"));
        ok(f128.is_tagged() && f128.tag() == 87, "float128 passthrough");
    }
    // multi-dim: 1040 column-major round trip, 40 row-major decode
    {
        std::vector<float> m6 = {1, 2, 3, 4, 5, 6};
        Value nd = Value::ndarray({2, 3}, m6);
        chk(nd, "d9041082820203d85558180000803f0000004000004040000080400000a0400000c040");
        rt(nd, "2x3 f32 (tag 1040)");
        std::vector<uint16_t> m24(24);
        for (int i = 0; i < 24; ++i) m24[i] = static_cast<uint16_t>(i + 1);
        rt(Value::ndarray({2, 3, 4}, m24), "2x3x4 u16 (tag 1040)");
        Value rm = cbor::decode(hx("d8288282020386010203040506"));   // tag 40, plain data
        ok(rm.is_ndarray() && rm.row_major() && rm.dims() == std::vector<uint64_t>({2, 3}) &&
           rm.to_doubles() == std::vector<double>({1, 2, 3, 4, 5, 6}), "tag 40 plain-array data");
        Value rm2 = cbor::decode(hx("d82882820203d8465818010000000200000003000000040000000500000006000000"));
        ok(rm2.is_ndarray() && rm2.row_major() && rm2.elem() == cbor::Elem::u32, "tag 40 typed data");
        rt(Value::ndarray({2, 2}, std::vector<int32_t>{1, 2, 3, 4}, true), "row-major nd round trip");
        ok(nd != Value(m6), "ndarray != flat typed");
        echk("d9041082820203d8464401000000", "multidim");     // dims 2x3 but 1 element
        try { Value::ndarray({2, 2}, std::vector<int>{1, 2, 3}); ok(false, "bad dims throws"); }
        catch (const cbor::error& e) { ok(e.id == "multidim", "bad dims -> multidim"); }
    }
    echk("d855450000000000", "typedarray");                   // 5 B under float32 tag
    chk(Value(std::vector<double>{}), "d85640");              // empty typed array stays typed

    // ---- 9. malformed input -----------------------------------------------
    std::puts("malformed ...");
    echk("19", "eof");          // truncated argument
    echk("ff", "break");        // top-level break
    echk("1c", "reserved");     // reserved additional info
    echk("8201ff", "break");    // break inside definite array
    echk("4403", "eof");        // truncated byte string
    echk("9f01", "eof");        // unterminated indefinite array
    echk("1f", "reserved");     // indefinite integer
    echk("5f4101", "eof");      // unterminated indefinite bytes
    echk("5f6101ff", "chunk");  // text chunk inside indefinite bytes
    echk("5f5f4101ffff", "chunk"); // nested indefinite chunk
    echk("a1", "eof");          // map without entries
    echk("9a7fffffff", "eof");  // absurd array length
    echk("", "eof");            // empty input
    {
        std::string deep(600, '\x81');                       // 600 nested arrays
        Bytes b(deep.begin(), deep.end()); b.push_back(0);
        try { cbor::decode(b); ok(false, "depth limit"); }
        catch (const cbor::error& e) { ok(e.id == "depth", "depth limit -> depth"); }
    }

    // ---- 10. Writer streaming API and sequences ---------------------------
    std::puts("writer ...");
    {
        cbor::Writer w;
        w.array_indef().integer(1).text("x").brk();
        ok(w.buf == hx("9f016178ff"), "indefinite array via Writer");
        w.clear();
        w.map_indef().text("k").float16(1.5).brk();
        ok(w.buf == hx("bf616bf93e00ff"), "indefinite map via Writer");
        w.clear();
        w.map(2).text("a").uinteger(1).text("b").float64(0.5);
        ok(cbor::decode(w.buf) == Value::map({{"a", 1}, {"b", 0.5}}), "definite map via Writer");
        w.clear();
        w.write(1).write("two").write(3.0f);
        auto seq = cbor::decode_all(w.buf);
        ok(seq.size() == 3 && seq[0] == 1 && seq[1] == "two" && seq[2] == 3.0f, "decode_all sequence");
        size_t pos = 0;
        Value a = cbor::decode(w.buf, pos);
        Value b = cbor::decode(w.buf, pos);
        ok(a == 1 && b == "two" && pos == 5, "decode with pos");
        cbor::Reader r(w.buf);
        int n = 0;
        while (!r.done()) { r.next(); ++n; }
        ok(n == 3 && r.position() == w.buf.size(), "Reader loop");
    }

    // ---- 11. streaming sequence (the logger layout) -----------------------
    std::puts("stream ...");
    {
        Bytes stream = logger_stream();
        ok(Bytes(stream.begin(), stream.begin() + 3) == hx("d9d9f7"), "stream starts with magic");
        cbor::Reader r(stream);
        Value hdr = r.next();
        ok(hdr.is_map() && hdr["dev"] == "imu0" && hdr["t0"].as_uint64() == 1756944000 &&
           hdr["fields"][1] == "ax", "stream header");
        int nblk = 0;
        Value blk;
        while (!r.done()) {
            blk = r.next();
            ++nblk;
            ok(blk.is_array() && blk.size() == 2 && blk[0].elem() == cbor::Elem::u32 &&
               blk[1].elem() == cbor::Elem::f32 && blk[0].count() == 4,
               "block " + std::to_string(nblk) + " types");
        }
        ok(nblk == 3 && blk[0].typed<uint32_t>().back() == 110, "stream block count/values");
        // every block has the same byte length -> O(1) seek
        size_t hdr_len = 0; { cbor::Reader h(stream); h.next(); hdr_len = h.position(); }
        ok((stream.size() - hdr_len) % 3 == 0, "fixed block stride");
        // truncated final block: earlier blocks stay readable, then eof
        Bytes cut(stream.begin(), stream.end() - 5);
        cbor::Reader rc(cut);
        int good = 0;
        try { while (!rc.done()) { rc.next(); ++good; } ok(false, "truncated stream must throw"); }
        catch (const cbor::error& e) { ok(e.id == "eof" && good == 3, "truncated block -> eof after 3 items"); }
    }

    std::printf("\n%d passed, %d failed\n", n_pass, n_fail);
    if (n_fail) {
        std::fprintf(stderr, "failures:\n");
        for (auto& f : failures) std::fprintf(stderr, "  %s\n", f.c_str());
    }
    return n_fail ? 1 : 0;
}

int main(int argc, char** argv) {
    if (argc == 3 && std::string(argv[1]) == "--write") {
        Bytes b = logger_stream();
        std::ofstream f(argv[2], std::ios::binary);
        f.write(reinterpret_cast<const char*>(b.data()), static_cast<std::streamsize>(b.size()));
        std::printf("wrote %zu bytes to %s\n", b.size(), argv[2]);
        return 0;
    }
    if (argc == 3 && std::string(argv[1]) == "--read") {
        std::ifstream f(argv[2], std::ios::binary);
        Bytes b((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
        try {
            for (const Value& v : cbor::decode_all(b)) std::puts(cbor::diag(v).c_str());
        } catch (const cbor::error& e) {
            std::fprintf(stderr, "%s\n", e.what());
            return 1;
        }
        return 0;
    }
    return run_tests();
}
