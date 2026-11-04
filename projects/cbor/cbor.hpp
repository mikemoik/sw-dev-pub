// cbor.hpp -- single-header CBOR codec (RFC 8949) with RFC 8746 typed arrays.
//
// C++17, no dependencies beyond the standard library, no exceptions besides
// cbor::error.  This is the C++ twin of cborenc.m / cbordec.m: same
// wire conventions, same type mapping philosophy ("what you cast is what you
// get"), same logger stream layout.  See CBOR_CHEATSHEET.md.
//
//   #include "cbor.hpp"
//   cbor::Value hdr = cbor::Value::map({{"v", 1u}, {"dev", "imu0"}});
//   std::vector<uint8_t> b = cbor::encode(cbor::Value::tagged(55799, hdr));
//   cbor::Value v = cbor::decode(b);            // tag 55799 unwrapped
//   v["dev"].as_text();                         // "imu0"
//
// Structs: describe a struct once (cbor_fields() or CBOR_FIELDS), then
//   cbor::to_value(s) / cbor::from_value<S>(v) -- see "Structs <-> CBOR maps".
//
// Three layers:
//   cbor::Writer  -- low-level streaming emitter (heads, typed arrays, indefinite
//                    containers), appends to a std::vector<uint8_t>.
//   cbor::Value   -- generic in-memory model: null/undefined/bool/int/float/
//                    bytes/text/array/map/tagged/simple/typed array/ND array.
//   cbor::Reader  -- generic decoder for a CBOR sequence (RFC 8742): Value next().
//
// Encoding rules (C++ type decides the CBOR type, nothing is guessed):
//   nullptr                  -> null 0xf6
//   bool                     -> true / false
//   signed/unsigned integers -> major 0/1, shortest head
//   float                    -> float32 0xfa   (5 B)
//   double                   -> float64 0xfb   (9 B)
//   cbor::f16{x}             -> float16 0xf9   (3 B), round-to-nearest-even
//   const char*/std::string  -> text string (major 3), bytes passed through as UTF-8
//   std::vector<uint8_t>     -> byte string (major 2)   (like MATLAB uint8 row)
//   std::vector<T> numeric   -> RFC 8746 typed array, little-endian tag + bytes
//   Value::ndarray(dims, v)  -> tag 1040 (column-major) [dims, typed array]
//   std::vector<Value>       -> array (major 4)
//   Value::map({...})        -> map (major 5), insertion order preserved
//   Value::tagged(n, v)      -> tag n (major 6)
//
// Decoding rules:
//   integers -> Int (int64) when they fit, else Uint (uint64); below INT64_MIN
//   errors ("range").  float16/32/64 -> Float (double + recorded width, so
//   round trips keep the width).  Text is not UTF-8 validated.  Map keys may be
//   any Value.  Tag 55799 unwraps silently.  Tags 64..87 (both byte orders)
//   -> Typed, stored in host order; float16 arrays widen to float64; float128
//   passes through as Tagged.  Tags 40/1040 with a typed-array payload ->
//   NDArray (dims + row/column-major flag).  Other tags -> Tagged.
//   Indefinite-length strings/arrays/maps are accepted, chunks concatenated.
//   Malformed input throws cbor::error with a short id (eof, break, reserved,
//   chunk, typedarray, multidim, range, depth, type).
//
// Not deterministic encoding (RFC 8949 s4.2): map keys stay in insertion order.

#ifndef CBOR_HPP_INCLUDED
#define CBOR_HPP_INCLUDED

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <tuple>
#include <type_traits>
#include <utility>
#include <vector>

namespace cbor {

// ---------------------------------------------------------------------------
// errors

struct error : std::runtime_error {
    std::string id;   // "eof", "break", "reserved", "chunk", "typedarray",
                      // "multidim", "range", "depth", "type", "unsupported"
    error(std::string id_, const std::string& msg)
        : std::runtime_error("cbor:" + id_ + ": " + msg), id(std::move(id_)) {}
};

// ---------------------------------------------------------------------------
// element types of typed arrays

enum class Elem : uint8_t { u8, u16, u32, u64, i8, i16, i32, i64, f32, f64 };

inline size_t elem_width(Elem e) {
    switch (e) {
        case Elem::u8: case Elem::i8: return 1;
        case Elem::u16: case Elem::i16: return 2;
        case Elem::u32: case Elem::i32: case Elem::f32: return 4;
        default: return 8;
    }
}

inline const char* elem_name(Elem e) {
    static const char* names[] = {"u8", "u16", "u32", "u64", "i8", "i16",
                                  "i32", "i64", "f32", "f64"};
    return names[static_cast<int>(e)];
}

// little-endian RFC 8746 tag for an element type (what the encoder emits)
inline uint64_t elem_tag_le(Elem e) {
    switch (e) {
        case Elem::u8:  return 64;
        case Elem::u16: return 69;
        case Elem::u32: return 70;
        case Elem::u64: return 71;
        case Elem::i8:  return 72;
        case Elem::i16: return 77;
        case Elem::i32: return 78;
        case Elem::i64: return 79;
        case Elem::f32: return 85;
        default:        return 86;
    }
}

template <class T>
constexpr bool is_typed_elem_v =
    std::is_arithmetic_v<T> && !std::is_same_v<T, bool> &&
    !std::is_same_v<T, char> && !std::is_same_v<T, wchar_t> &&
    !std::is_same_v<T, char16_t> && !std::is_same_v<T, char32_t> &&
    (std::is_floating_point_v<T> ? (sizeof(T) == 4 || sizeof(T) == 8)
                                 : (sizeof(T) <= 8));

template <class T>
constexpr Elem elem_of() {
    static_assert(is_typed_elem_v<T>, "no typed-array element type for T");
    if constexpr (std::is_floating_point_v<T>) {
        return sizeof(T) == 4 ? Elem::f32 : Elem::f64;
    } else if constexpr (std::is_signed_v<T>) {
        return sizeof(T) == 1 ? Elem::i8 : sizeof(T) == 2 ? Elem::i16
             : sizeof(T) == 4 ? Elem::i32 : Elem::i64;
    } else {
        return sizeof(T) == 1 ? Elem::u8 : sizeof(T) == 2 ? Elem::u16
             : sizeof(T) == 4 ? Elem::u32 : Elem::u64;
    }
}

// ---------------------------------------------------------------------------
// small helpers

namespace detail {

inline bool host_little() {
    uint16_t x = 1;
    uint8_t b;
    std::memcpy(&b, &x, 1);
    return b == 1;
}

inline void swap_in_place(uint8_t* p, size_t n, size_t w) {
    for (size_t i = 0; i < n; i += w)
        for (size_t a = 0, b = w - 1; a < b; ++a, --b)
            std::swap(p[i + a], p[i + b]);
}

inline uint64_t load_be(const uint8_t* p, size_t n) {
    uint64_t v = 0;
    for (size_t i = 0; i < n; ++i) v = (v << 8) | p[i];
    return v;
}

// IEEE 754 binary16 from double, round-to-nearest-even, subnormals,
// overflow -> Inf, NaN -> canonical 0x7e00.
inline uint16_t f16_bits(double x) {
    uint64_t u;
    std::memcpy(&u, &x, 8);
    uint16_t sgn = static_cast<uint16_t>((u >> 63) << 15);
    int expo = static_cast<int>((u >> 52) & 0x7ff) - 1023;
    uint64_t mant = u & ((uint64_t(1) << 52) - 1);
    uint16_t h;
    if (expo == 1024) {                            // Inf / NaN
        return mant ? uint16_t(0x7e00) : uint16_t(0x7c00 | sgn);
    } else if (expo > 15) {                        // overflow
        h = 0x7c00;
    } else if (expo >= -14) {                      // normal: keep 10 of 52 bits
        uint64_t q = mant >> 42, r = mant & ((uint64_t(1) << 42) - 1);
        const uint64_t half = uint64_t(1) << 41;
        if (r > half || (r == half && (q & 1))) ++q;
        h = static_cast<uint16_t>((uint64_t(expo + 15) << 10) + q);  // carry -> exp
    } else if (expo >= -25) {                      // subnormal
        uint64_t m = mant | (uint64_t(1) << 52);
        int s = 28 - expo;                         // 43..53
        uint64_t q = m >> s, r = m & ((uint64_t(1) << s) - 1);
        const uint64_t half = uint64_t(1) << (s - 1);
        if (r > half || (r == half && (q & 1))) ++q;
        h = static_cast<uint16_t>(q);
    } else {
        h = 0;                                     // underflow -> signed zero
    }
    return static_cast<uint16_t>(h | sgn);
}

inline double f16_value(uint16_t h) {
    int s = (h >> 15) ? -1 : 1;
    int e = (h >> 10) & 0x1f;
    int m = h & 0x3ff;
    if (e == 0) return s * std::ldexp(double(m), -24);
    if (e == 31) return m ? std::nan("") : s * HUGE_VAL;
    return s * std::ldexp(double(1024 + m), e - 25);
}

}  // namespace detail

// marker type: encode this double as float16
struct f16 {
    double v;
    explicit f16(double x) : v(x) {}
};

// ---------------------------------------------------------------------------
// Value: generic in-memory model

enum class Type : uint8_t {
    Null, Undefined, Bool, Int, Uint, Float, Bytes, Text, Array, Map,
    Tagged, Simple, Typed, NDArray
};

inline const char* type_name(Type t) {
    static const char* names[] = {"null", "undefined", "bool", "int", "uint",
                                  "float", "bytes", "text", "array", "map",
                                  "tagged", "simple", "typed", "ndarray"};
    return names[static_cast<int>(t)];
}

class Value {
public:
    using Array = std::vector<Value>;
    using Map = std::vector<std::pair<Value, Value>>;

    // ---- construction ------------------------------------------------------
    Value() = default;
    Value(std::nullptr_t) {}
    Value(bool b) : t_(Type::Bool), b_(b) {}

    template <class T, std::enable_if_t<std::is_integral_v<T> && !std::is_same_v<T, bool>, int> = 0>
    Value(T n) {
        if constexpr (std::is_signed_v<T>) {
            t_ = Type::Int; i_ = static_cast<int64_t>(n);
        } else {
            if (static_cast<uint64_t>(n) <= static_cast<uint64_t>(INT64_MAX)) {
                t_ = Type::Int; i_ = static_cast<int64_t>(n);
            } else {
                t_ = Type::Uint; u_ = static_cast<uint64_t>(n);
            }
        }
    }
    Value(float x) : t_(Type::Float), d_(x), width_(4) {}
    Value(double x) : t_(Type::Float), d_(x), width_(8) {}
    Value(f16 x) : t_(Type::Float), d_(x.v), width_(2) {}
    Value(const char* s) : t_(Type::Text), s_(s) {}
    Value(std::string s) : t_(Type::Text), s_(std::move(s)) {}
    Value(std::string_view s) : t_(Type::Text), s_(s) {}
    Value(std::vector<uint8_t> b) : t_(Type::Bytes), raw_(std::move(b)) {}
    Value(Array a) : t_(Type::Array), kids_(std::move(a)) {}

    // numeric std::vector<T> (T != uint8_t) -> typed array
    template <class T, std::enable_if_t<is_typed_elem_v<T> && !std::is_same_v<T, uint8_t>, int> = 0>
    Value(const std::vector<T>& v) { set_typed(v.data(), v.size()); }

    static Value undefined() { Value v; v.t_ = Type::Undefined; return v; }
    static Value simple(uint8_t n) {
        if (n >= 24 && n < 32) throw error("reserved", "simple values 24..31 are reserved");
        Value v; v.t_ = Type::Simple; v.u_ = n; return v;
    }
    static Value bytes(const uint8_t* p, size_t n) { return Value(std::vector<uint8_t>(p, p + n)); }
    static Value array(std::initializer_list<Value> items) { return Value(Array(items)); }
    static Value array(Array items) { return Value(std::move(items)); }
    static Value map(std::initializer_list<std::pair<Value, Value>> entries) {
        Value v; v.t_ = Type::Map; v.map_.assign(entries.begin(), entries.end()); return v;
    }
    static Value map(Map entries) { Value v; v.t_ = Type::Map; v.map_ = std::move(entries); return v; }
    static Value tagged(uint64_t tag, Value content) {
        Value v; v.t_ = Type::Tagged; v.u_ = tag; v.kids_.push_back(std::move(content)); return v;
    }
    template <class T>
    static Value typed(const T* p, size_t n) { Value v; v.set_typed(p, n); return v; }
    template <class T>
    static Value typed(const std::vector<T>& d) { return typed(d.data(), d.size()); }
    // raw typed array from bytes already in host order
    static Value typed_raw(Elem e, std::vector<uint8_t> host_bytes) {
        if (host_bytes.size() % elem_width(e))
            throw error("typedarray", "byte count not a multiple of element width");
        Value v; v.t_ = Type::Typed; v.elem_ = e; v.raw_ = std::move(host_bytes); return v;
    }
    // multi-dimensional array: dims + flat data, column-major (tag 1040, the
    // MATLAB layout) unless row_major = true (tag 40)
    template <class T>
    static Value ndarray(std::vector<uint64_t> dims, const std::vector<T>& d, bool row_major = false) {
        uint64_t n = 1;
        for (uint64_t k : dims) n *= k;
        if (n != d.size()) throw error("multidim", "dims do not match data size");
        Value v = typed(d);
        v.t_ = Type::NDArray; v.dims_ = std::move(dims); v.rowmajor_ = row_major;
        return v;
    }

    // ---- building ----------------------------------------------------------
    Value& push(Value v) { need(Type::Array); kids_.push_back(std::move(v)); return *this; }
    Value& set(Value key, Value val) {           // replace or append (map)
        need(Type::Map);
        for (auto& kv : map_) if (kv.first == key) { kv.second = std::move(val); return *this; }
        map_.emplace_back(std::move(key), std::move(val));
        return *this;
    }

    // ---- inspection --------------------------------------------------------
    Type type() const { return t_; }
    bool is_null() const { return t_ == Type::Null; }
    bool is_undefined() const { return t_ == Type::Undefined; }
    bool is_bool() const { return t_ == Type::Bool; }
    bool is_int() const { return t_ == Type::Int || t_ == Type::Uint; }
    bool is_float() const { return t_ == Type::Float; }
    bool is_number() const { return is_int() || is_float(); }
    bool is_bytes() const { return t_ == Type::Bytes; }
    bool is_text() const { return t_ == Type::Text; }
    bool is_array() const { return t_ == Type::Array; }
    bool is_map() const { return t_ == Type::Map; }
    bool is_tagged() const { return t_ == Type::Tagged; }
    bool is_simple() const { return t_ == Type::Simple; }
    bool is_typed() const { return t_ == Type::Typed || t_ == Type::NDArray; }
    bool is_ndarray() const { return t_ == Type::NDArray; }

    bool as_bool() const { need(Type::Bool); return b_; }
    int64_t as_int64() const {
        if (t_ == Type::Int) return i_;
        if (t_ == Type::Uint) throw error("range", "value exceeds int64");
        throw error("type", std::string("expected int, got ") + type_name(t_));
    }
    uint64_t as_uint64() const {
        if (t_ == Type::Uint) return u_;
        if (t_ == Type::Int && i_ >= 0) return static_cast<uint64_t>(i_);
        if (t_ == Type::Int) throw error("range", "negative value as uint64");
        throw error("type", std::string("expected int, got ") + type_name(t_));
    }
    double as_double() const {                     // any number
        if (t_ == Type::Float) return d_;
        if (t_ == Type::Int) return static_cast<double>(i_);
        if (t_ == Type::Uint) return static_cast<double>(u_);
        throw error("type", std::string("expected number, got ") + type_name(t_));
    }
    int float_width() const { need(Type::Float); return width_; }   // 2, 4, 8

    // Checked conversion to a C++ scalar: the target type decides.
    //   integer T : CBOR int whose value fits T, else error "range"
    //               (a float is a "type" error -- no silent truncation)
    //   float/double: any number; finite values beyond the float range -> "range"
    //   bool, std::string: exact CBOR type (as_bool / as_text)
    template <class T>
    T as() const {
        if constexpr (std::is_same_v<T, bool>) {
            return as_bool();
        } else if constexpr (std::is_integral_v<T>) {
            if (t_ == Type::Int) {
                if constexpr (std::is_signed_v<T>) {
                    if (i_ < static_cast<int64_t>(std::numeric_limits<T>::min()) ||
                        i_ > static_cast<int64_t>(std::numeric_limits<T>::max()))
                        throw error("range", std::to_string(i_) + " does not fit " + int_name<T>());
                } else {
                    if (i_ < 0 || static_cast<uint64_t>(i_) > std::numeric_limits<T>::max())
                        throw error("range", std::to_string(i_) + " does not fit " + int_name<T>());
                }
                return static_cast<T>(i_);
            }
            if (t_ == Type::Uint) {
                if (u_ > static_cast<uint64_t>(std::numeric_limits<T>::max()))
                    throw error("range", std::to_string(u_) + " does not fit " + int_name<T>());
                return static_cast<T>(u_);
            }
            throw error("type", std::string("expected int, got ") + type_name(t_));
        } else if constexpr (std::is_floating_point_v<T>) {
            double d = as_double();
            if (std::isfinite(d) && std::fabs(d) > static_cast<double>(std::numeric_limits<T>::max()))
                throw error("range", std::to_string(d) + " does not fit float");
            return static_cast<T>(d);
        } else if constexpr (std::is_same_v<T, std::string>) {
            return as_text();
        } else {
            static_assert(std::is_arithmetic_v<T>, "as<T>: T must be bool, an integer, a float type or std::string");
        }
    }
    const std::string& as_text() const { need(Type::Text); return s_; }
    const std::vector<uint8_t>& as_bytes() const { need(Type::Bytes); return raw_; }
    const Array& as_array() const { need(Type::Array); return kids_; }
    Array& as_array() { need(Type::Array); return kids_; }
    const Map& as_map() const { need(Type::Map); return map_; }
    Map& as_map() { need(Type::Map); return map_; }
    uint64_t tag() const { need(Type::Tagged); return u_; }
    const Value& content() const { need(Type::Tagged); return kids_[0]; }
    uint8_t simple_value() const { need(Type::Simple); return static_cast<uint8_t>(u_); }

    // typed arrays
    Elem elem() const { need_typed(); return elem_; }
    size_t count() const { need_typed(); return raw_.size() / elem_width(elem_); }
    const std::vector<uint8_t>& raw() const { need_typed(); return raw_; }   // host order
    template <class T>
    std::vector<T> typed() const {               // exact element type required
        need_typed();
        if (elem_of<T>() != elem_)
            throw error("type", std::string("typed array is ") + elem_name(elem_) +
                                ", not " + elem_name(elem_of<T>()));
        std::vector<T> out(count());
        if (!out.empty()) std::memcpy(out.data(), raw_.data(), raw_.size());
        return out;
    }
    template <class T>
    const T* data() const {                      // zero-copy view, host order
        need_typed();
        if (elem_of<T>() != elem_)
            throw error("type", std::string("typed array is ") + elem_name(elem_));
        return reinterpret_cast<const T*>(raw_.data());
    }
    std::vector<double> to_doubles() const {     // any typed array, widened
        need_typed();
        std::vector<double> out(count());
        for (size_t k = 0; k < out.size(); ++k) out[k] = elem_as_double(k);
        return out;
    }
    const std::vector<uint64_t>& dims() const { need(Type::NDArray); return dims_; }
    bool row_major() const { need(Type::NDArray); return rowmajor_; }

    // containers
    size_t size() const {
        switch (t_) {
            case Type::Array: return kids_.size();
            case Type::Map: return map_.size();
            case Type::Bytes: return raw_.size();
            case Type::Text: return s_.size();
            case Type::Typed: case Type::NDArray: return count();
            default: throw error("type", std::string("no size for ") + type_name(t_));
        }
    }
    template <class I, std::enable_if_t<std::is_integral_v<I>, int> = 0>
    const Value& operator[](I i) const {             // array index (any integer type)
        need(Type::Array);
        if constexpr (std::is_signed_v<I>) {
            if (i < 0) throw error("range", "negative array index");
        }
        if (static_cast<uint64_t>(i) >= kids_.size()) throw error("range", "array index out of range");
        return kids_[static_cast<size_t>(i)];
    }
    const Value* find(std::string_view key) const {
        need(Type::Map);
        for (auto& kv : map_) if (kv.first.t_ == Type::Text && kv.first.s_ == key) return &kv.second;
        return nullptr;
    }
    const Value& operator[](std::string_view key) const {
        if (const Value* v = find(key)) return *v;
        throw error("range", "missing map key '" + std::string(key) + "'");
    }
    const Value& operator[](const char* key) const { return (*this)[std::string_view(key)]; }
    bool contains(std::string_view key) const { return find(key) != nullptr; }

    // structural equality; NaN == NaN (like MATLAB isequaln); float width and
    // typed element type must match
    friend bool operator==(const Value& a, const Value& b) {
        if (a.t_ != b.t_) return false;
        switch (a.t_) {
            case Type::Null: case Type::Undefined: return true;
            case Type::Bool: return a.b_ == b.b_;
            case Type::Int: return a.i_ == b.i_;
            case Type::Uint: case Type::Simple: return a.u_ == b.u_;
            case Type::Float:
                return a.width_ == b.width_ &&
                       (a.d_ == b.d_ || (std::isnan(a.d_) && std::isnan(b.d_)));
            case Type::Bytes: return a.raw_ == b.raw_;
            case Type::Text: return a.s_ == b.s_;
            case Type::Array: return a.kids_ == b.kids_;
            case Type::Map: return a.map_ == b.map_;
            case Type::Tagged: return a.u_ == b.u_ && a.kids_ == b.kids_;
            case Type::Typed: case Type::NDArray:
                if (a.elem_ != b.elem_ || a.dims_ != b.dims_ || a.rowmajor_ != b.rowmajor_ ||
                    a.raw_.size() != b.raw_.size()) return false;
                if (a.elem_ == Elem::f32 || a.elem_ == Elem::f64) {
                    for (size_t k = 0; k < a.count(); ++k) {
                        double x = a.elem_as_double(k), y = b.elem_as_double(k);
                        if (!(x == y || (std::isnan(x) && std::isnan(y)))) return false;
                    }
                    return true;
                }
                return a.raw_ == b.raw_;
        }
        return false;
    }
    friend bool operator!=(const Value& a, const Value& b) { return !(a == b); }

private:
    friend class Writer;
    friend class Reader;
    friend std::string diag(const Value&);

    template <class T>
    static std::string int_name() {
        return std::string(std::is_signed_v<T> ? "int" : "uint") + std::to_string(8 * sizeof(T));
    }
    void need(Type t) const {
        if (t_ != t)
            throw error("type", std::string("expected ") + type_name(t) + ", got " + type_name(t_));
    }
    void need_typed() const {
        if (!is_typed())
            throw error("type", std::string("expected typed array, got ") + type_name(t_));
    }
    template <class T>
    void set_typed(const T* p, size_t n) {
        t_ = Type::Typed;
        elem_ = elem_of<T>();
        raw_.resize(n * sizeof(T));
        if (n) std::memcpy(raw_.data(), p, n * sizeof(T));
    }
    std::string elem_int_string(size_t k) const {   // integer element, exact (no double detour)
        const uint8_t* p = raw_.data() + k * elem_width(elem_);
        switch (elem_) {
            case Elem::u64: { uint64_t v; std::memcpy(&v, p, 8); return std::to_string(v); }
            case Elem::i64: { int64_t v;  std::memcpy(&v, p, 8); return std::to_string(v); }
            default:        return std::to_string(static_cast<int64_t>(elem_as_double(k)));  // <= 32 bit: exact
        }
    }
    double elem_as_double(size_t k) const {
        const uint8_t* p = raw_.data() + k * elem_width(elem_);
        switch (elem_) {
            case Elem::u8:  return p[0];
            case Elem::i8:  return static_cast<int8_t>(p[0]);
            case Elem::u16: { uint16_t v; std::memcpy(&v, p, 2); return v; }
            case Elem::i16: { int16_t v;  std::memcpy(&v, p, 2); return v; }
            case Elem::u32: { uint32_t v; std::memcpy(&v, p, 4); return v; }
            case Elem::i32: { int32_t v;  std::memcpy(&v, p, 4); return v; }
            case Elem::u64: { uint64_t v; std::memcpy(&v, p, 8); return static_cast<double>(v); }
            case Elem::i64: { int64_t v;  std::memcpy(&v, p, 8); return static_cast<double>(v); }
            case Elem::f32: { float v;    std::memcpy(&v, p, 4); return v; }
            default:        { double v;   std::memcpy(&v, p, 8); return v; }
        }
    }

    Type t_ = Type::Null;
    bool b_ = false;
    int64_t i_ = 0;
    uint64_t u_ = 0;          // Uint value, tag number, simple value
    double d_ = 0;
    uint8_t width_ = 8;       // float width on the wire: 2, 4, 8
    Elem elem_ = Elem::u8;
    bool rowmajor_ = false;
    std::string s_;
    std::vector<uint8_t> raw_;      // Bytes payload, Typed/NDArray data (host order)
    Array kids_;                    // Array items, Tagged content [0]
    Map map_;
    std::vector<uint64_t> dims_;
};

// ---------------------------------------------------------------------------
// Writer: low-level emitter

class Writer {
public:
    std::vector<uint8_t> buf;

    Writer& head(int major, uint64_t n) {
        uint8_t m = static_cast<uint8_t>(major << 5);
        if (n < 24) {
            buf.push_back(static_cast<uint8_t>(m | n));
        } else if (n < 0x100) {
            buf.push_back(m | 24); buf.push_back(static_cast<uint8_t>(n));
        } else if (n < 0x10000) {
            buf.push_back(m | 25); be(n, 2);
        } else if (n < 0x100000000ULL) {
            buf.push_back(m | 26); be(n, 4);
        } else {
            buf.push_back(m | 27); be(n, 8);
        }
        return *this;
    }

    Writer& null() { buf.push_back(0xf6); return *this; }
    Writer& undefined() { buf.push_back(0xf7); return *this; }
    Writer& boolean(bool b) { buf.push_back(b ? 0xf5 : 0xf4); return *this; }
    Writer& integer(int64_t n) {
        return n >= 0 ? head(0, static_cast<uint64_t>(n)) : head(1, ~static_cast<uint64_t>(n));
    }
    Writer& uinteger(uint64_t n) { return head(0, n); }
    Writer& simple(uint8_t n) {
        if (n >= 24 && n < 32) throw error("reserved", "simple values 24..31 are reserved");
        if (n < 24) buf.push_back(static_cast<uint8_t>(0xe0 | n));
        else { buf.push_back(0xf8); buf.push_back(n); }
        return *this;
    }
    Writer& float16(double x) {
        buf.push_back(0xf9); be(detail::f16_bits(x), 2); return *this;
    }
    Writer& float32(float x) {
        uint32_t u;
        if (std::isnan(x)) u = 0x7fc00000u;                 // canonical NaN
        else std::memcpy(&u, &x, 4);
        buf.push_back(0xfa); be(u, 4); return *this;
    }
    Writer& float64(double x) {
        uint64_t u;
        if (std::isnan(x)) u = 0x7ff8000000000000ULL;       // canonical NaN
        else std::memcpy(&u, &x, 8);
        buf.push_back(0xfb); be(u, 8); return *this;
    }
    Writer& text(std::string_view s) {
        head(3, s.size()); buf.insert(buf.end(), s.begin(), s.end()); return *this;
    }
    Writer& bytes(const uint8_t* p, size_t n) {
        head(2, n); buf.insert(buf.end(), p, p + n); return *this;
    }
    Writer& bytes(const std::vector<uint8_t>& b) { return bytes(b.data(), b.size()); }
    Writer& tag(uint64_t n) { return head(6, n); }
    Writer& array(size_t n) { return head(4, n); }        // followed by n items
    Writer& map(size_t n) { return head(5, n); }          // followed by n key/value pairs
    Writer& array_indef() { buf.push_back(0x9f); return *this; }
    Writer& map_indef() { buf.push_back(0xbf); return *this; }
    Writer& brk() { buf.push_back(0xff); return *this; }

    // RFC 8746 typed array: little-endian tag + packed byte string
    template <class T>
    Writer& typed(const T* p, size_t n) {
        static_assert(is_typed_elem_v<T>, "not a typed-array element type");
        return typed_raw(elem_of<T>(), reinterpret_cast<const uint8_t*>(p), n * sizeof(T));
    }
    template <class T>
    Writer& typed(const std::vector<T>& v) { return typed(v.data(), v.size()); }
    Writer& typed_raw(Elem e, const uint8_t* host_bytes, size_t n) {
        tag(elem_tag_le(e));
        head(2, n);
        size_t at = buf.size();
        buf.insert(buf.end(), host_bytes, host_bytes + n);
        if (!detail::host_little() && elem_width(e) > 1)
            detail::swap_in_place(buf.data() + at, n, elem_width(e));
        return *this;
    }
    // RFC 8746 multi-dim: tag 1040 (column-major) or 40 (row-major) [[dims], typed]
    template <class T>
    Writer& ndarray(const std::vector<uint64_t>& dims, const T* p, size_t n, bool row_major = false) {
        uint64_t total = 1;
        for (uint64_t k : dims) total *= k;
        if (total != n) throw error("multidim", "dims do not match data size");
        tag(row_major ? 40 : 1040).array(2).array(dims.size());
        for (uint64_t k : dims) uinteger(k);
        return typed(p, n);
    }
    template <class T>
    Writer& ndarray(const std::vector<uint64_t>& dims, const std::vector<T>& v, bool row_major = false) {
        return ndarray(dims, v.data(), v.size(), row_major);
    }

    Writer& value(const Value& v) {
        switch (v.t_) {
            case Type::Null: return null();
            case Type::Undefined: return undefined();
            case Type::Bool: return boolean(v.b_);
            case Type::Int: return integer(v.i_);
            case Type::Uint: return uinteger(v.u_);
            case Type::Float:
                return v.width_ == 2 ? float16(v.d_)
                     : v.width_ == 4 ? float32(static_cast<float>(v.d_)) : float64(v.d_);
            case Type::Bytes: return bytes(v.raw_);
            case Type::Text: return text(v.s_);
            case Type::Array:
                array(v.kids_.size());
                for (auto& k : v.kids_) value(k);
                return *this;
            case Type::Map:
                map(v.map_.size());
                for (auto& kv : v.map_) { value(kv.first); value(kv.second); }
                return *this;
            case Type::Tagged: tag(v.u_); return value(v.kids_[0]);
            case Type::Simple: return simple(static_cast<uint8_t>(v.u_));
            case Type::Typed: return typed_raw(v.elem_, v.raw_.data(), v.raw_.size());
            case Type::NDArray:
                tag(v.rowmajor_ ? 40 : 1040).array(2).array(v.dims_.size());
                for (uint64_t k : v.dims_) uinteger(k);
                return typed_raw(v.elem_, v.raw_.data(), v.raw_.size());
        }
        throw error("unsupported", "unknown value type");
    }
    template <class T>
    Writer& write(const T& x) { return value(Value(x)); }

    void clear() { buf.clear(); }

private:
    void be(uint64_t v, int n) {
        for (int i = n - 1; i >= 0; --i) buf.push_back(static_cast<uint8_t>(v >> (8 * i)));
    }
};

inline std::vector<uint8_t> encode(const Value& v) {
    Writer w;
    w.value(v);
    return std::move(w.buf);
}

// ---------------------------------------------------------------------------
// Reader: generic decoder over a byte range (CBOR sequence, RFC 8742)

class Reader {
public:
    static constexpr int max_depth = 512;

    Reader(const uint8_t* data, size_t size, size_t pos = 0) : p_(data), n_(size), pos_(pos) {}
    explicit Reader(const std::vector<uint8_t>& b, size_t pos = 0) : Reader(b.data(), b.size(), pos) {}

    bool done() const { return pos_ >= n_; }
    size_t position() const { return pos_; }
    size_t remaining() const { return n_ - pos_; }
    Value next() { return item(0); }

private:
    const uint8_t* p_;
    size_t n_;
    size_t pos_;

    uint8_t byte() {
        if (pos_ >= n_) throw error("eof", "truncated input at " + std::to_string(pos_));
        return p_[pos_++];
    }
    // argument for additional-info `ai`; indef set for 31
    uint64_t arg(uint8_t ai, bool& indef, int major) {
        indef = false;
        if (ai < 24) return ai;
        if (ai == 31) {
            if (major < 2 || major == 6) throw error("reserved", "indefinite length not allowed here");
            indef = true;
            return 0;
        }
        if (ai > 27) throw error("reserved", "reserved additional info " + std::to_string(ai));
        size_t len = size_t(1) << (ai - 24);
        if (pos_ + len > n_) throw error("eof", "truncated argument at " + std::to_string(pos_));
        uint64_t v = detail::load_be(p_ + pos_, len);
        pos_ += len;
        return v;
    }
    std::vector<uint8_t> string_body(bool indef, uint64_t n, int major, int depth) {
        std::vector<uint8_t> raw;
        if (!indef) {
            if (n > remaining()) throw error("eof", "truncated " + std::to_string(n) + "-byte string");
            raw.assign(p_ + pos_, p_ + pos_ + n);
            pos_ += static_cast<size_t>(n);
            return raw;
        }
        for (;;) {
            uint8_t ib = byte();
            if (ib == 0xff) return raw;
            int cm = ib >> 5, ci = ib & 31;
            if (cm != major || ci == 31)
                throw error("chunk", "indefinite string chunk must be a definite string of the same type");
            bool ci_indef;
            uint64_t cn = arg(static_cast<uint8_t>(ci), ci_indef, cm);
            auto chunk = string_body(false, cn, major, depth);
            raw.insert(raw.end(), chunk.begin(), chunk.end());
        }
    }

    Value item(int depth) {
        if (depth > max_depth) throw error("depth", "nesting deeper than max_depth");
        uint8_t ib = byte();
        int major = ib >> 5;
        uint8_t ai = ib & 31;
        if (ib == 0xff) throw error("break", "unexpected break at " + std::to_string(pos_ - 1));
        if (major == 7) return simple_or_float(ai);
        bool indef;
        uint64_t n = arg(ai, indef, major);
        switch (major) {
            case 0: return n <= static_cast<uint64_t>(INT64_MAX) ? Value(static_cast<int64_t>(n)) : Value(n);
            case 1:
                if (n > static_cast<uint64_t>(INT64_MAX))
                    throw error("range", "negative integer below INT64_MIN");
                return Value(static_cast<int64_t>(~n));
            case 2: return Value(string_body(indef, n, 2, depth));
            case 3: {
                auto raw = string_body(indef, n, 3, depth);
                return Value(std::string(raw.begin(), raw.end()));
            }
            case 4: {
                Value::Array items;
                if (indef) {
                    while (peek_not_break()) items.push_back(item(depth + 1));
                    ++pos_;
                } else {
                    if (n > remaining()) throw error("eof", "array length exceeds input");
                    items.reserve(static_cast<size_t>(n));
                    for (uint64_t k = 0; k < n; ++k) items.push_back(item(depth + 1));
                }
                return Value(std::move(items));
            }
            case 5: {
                Value::Map m;
                if (indef) {
                    while (peek_not_break()) {
                        Value k = item(depth + 1);
                        Value v = item(depth + 1);
                        m.emplace_back(std::move(k), std::move(v));
                    }
                    ++pos_;
                } else {
                    if (n > remaining() / 2) throw error("eof", "map length exceeds input");
                    m.reserve(static_cast<size_t>(n));
                    for (uint64_t k = 0; k < n; ++k) {
                        Value key = item(depth + 1);
                        Value v = item(depth + 1);
                        m.emplace_back(std::move(key), std::move(v));
                    }
                }
                return Value::map(std::move(m));
            }
            default: {  // 6: tag
                Value content = item(depth + 1);
                return tagged(n, std::move(content));
            }
        }
    }
    bool peek_not_break() {
        if (pos_ >= n_) throw error("eof", "unterminated indefinite container");
        return p_[pos_] != 0xff;
    }
    Value simple_or_float(uint8_t ai) {
        switch (ai) {
            case 20: return Value(false);
            case 21: return Value(true);
            case 22: return Value(nullptr);
            case 23: return Value::undefined();
            case 24: {
                uint8_t n = byte();
                if (n < 32) throw error("reserved", "two-byte simple value below 32");
                return Value::simple(n);
            }
            case 25: {
                bool d; uint64_t u = arg(25, d, 7);
                return Value(f16(detail::f16_value(static_cast<uint16_t>(u))));
            }
            case 26: {
                bool d; uint64_t u = arg(26, d, 7);
                uint32_t bits = static_cast<uint32_t>(u); float f;
                std::memcpy(&f, &bits, 4);
                return Value(f);
            }
            case 27: {
                bool d; uint64_t u = arg(27, d, 7);
                double x; std::memcpy(&x, &u, 8);
                return Value(x);
            }
            case 28: case 29: case 30: case 31:
                throw error("reserved", "reserved simple/float additional info");
            default: return Value::simple(ai);
        }
    }
    Value tagged(uint64_t tag, Value content) {
        if (tag == 55799) return content;                  // self-describe: unwrap
        if (tag >= 64 && tag <= 87 && content.is_bytes()) {
            Value v;
            if (typed_from_tag(tag, content.as_bytes(), v)) return v;
        }
        if ((tag == 40 || tag == 1040) && content.is_array() && content.size() == 2 &&
            content[0].is_array() && content[1].is_array()) {
            // plain-array data variant: array of numbers -> float64 typed array
            std::vector<double> d;
            for (auto& x : content[1].as_array()) {
                if (!x.is_number()) return Value::tagged(tag, std::move(content));
                d.push_back(x.as_double());
            }
            Value::Array a = content.as_array();
            a[1] = Value::typed(d);
            content = Value(std::move(a));
        }
        if ((tag == 40 || tag == 1040) && content.is_array() && content.size() == 2 &&
            content[0].is_array() && content[1].is_typed() && !content[1].is_ndarray()) {
            std::vector<uint64_t> dims;
            uint64_t total = 1;
            for (auto& d : content[0].as_array()) {
                if (!d.is_int()) throw error("multidim", "dimension is not an integer");
                dims.push_back(d.as_uint64());
                total *= dims.back();
            }
            if (total != content[1].count())
                throw error("multidim", "multi-dim data does not match dims");
            Value v = content[1];
            v.t_ = Type::NDArray; v.dims_ = std::move(dims); v.rowmajor_ = (tag == 40);
            return v;
        }
        return Value::tagged(tag, std::move(content));
    }
    // tags 64..87 -> typed array in host order; false for float128 / reserved
    static bool typed_from_tag(uint64_t tag, const std::vector<uint8_t>& raw, Value& out) {
        int k = static_cast<int>(tag - 64);
        bool is_float = k >= 16;
        bool sign = !is_float && (k & 8);
        bool little = (k & 4) != 0;                    // bit 2: little-endian
        int ll = k & 3;                                 // length code
        Elem e;
        size_t w;
        if (is_float) {
            if (ll == 0) {                              // float16 -> widen to f64
                if (raw.size() % 2) throw error("typedarray", "float16 array byte count is odd");
                std::vector<double> d(raw.size() / 2);
                for (size_t i = 0; i < d.size(); ++i) {
                    uint16_t h = little ? static_cast<uint16_t>(raw[2 * i] | (raw[2 * i + 1] << 8))
                                        : static_cast<uint16_t>((raw[2 * i] << 8) | raw[2 * i + 1]);
                    d[i] = detail::f16_value(h);
                }
                out = Value::typed(d);
                return true;
            }
            if (ll == 3) return false;                  // float128: passthrough
            e = ll == 1 ? Elem::f32 : Elem::f64;
        } else {
            if (k == 4) { e = Elem::u8; }               // clamped u8 -> u8
            else {
                static const Elem u[] = {Elem::u8, Elem::u16, Elem::u32, Elem::u64};
                static const Elem s[] = {Elem::i8, Elem::i16, Elem::i32, Elem::i64};
                e = sign ? s[ll] : u[ll];
            }
        }
        w = elem_width(e);
        if (raw.size() % w)
            throw error("typedarray", "byte count not a multiple of element width " + std::to_string(w));
        std::vector<uint8_t> host = raw;
        if (w > 1 && little != detail::host_little()) detail::swap_in_place(host.data(), host.size(), w);
        out = Value::typed_raw(e, std::move(host));
        return true;
    }
};

// decode one item; pos is advanced past it (0-based)
inline Value decode(const uint8_t* data, size_t size, size_t& pos) {
    Reader r(data, size, pos);
    Value v = r.next();
    pos = r.position();
    return v;
}
inline Value decode(const std::vector<uint8_t>& b, size_t& pos) { return decode(b.data(), b.size(), pos); }
inline Value decode(const std::vector<uint8_t>& b) { size_t pos = 0; return decode(b, pos); }

// decode a whole CBOR sequence
inline std::vector<Value> decode_all(const uint8_t* data, size_t size) {
    std::vector<Value> out;
    Reader r(data, size);
    while (!r.done()) out.push_back(r.next());
    return out;
}
inline std::vector<Value> decode_all(const std::vector<uint8_t>& b) { return decode_all(b.data(), b.size()); }

// ---------------------------------------------------------------------------
// diagnostic notation (RFC 8949 s8), for debugging / tests

inline std::string diag(const Value& v) {
    auto num = [](double d) {
        char buf[64];
        std::snprintf(buf, sizeof buf, "%.17g", d);
        std::string s = buf;
        if (s.find_first_of(".eEn") == std::string::npos) s += ".0";
        return s;
    };
    std::string s;
    switch (v.t_) {
        case Type::Null: return "null";
        case Type::Undefined: return "undefined";
        case Type::Bool: return v.b_ ? "true" : "false";
        case Type::Int: return std::to_string(v.i_);
        case Type::Uint: return std::to_string(v.u_);
        case Type::Float:
            if (std::isnan(v.d_)) return "NaN";
            if (std::isinf(v.d_)) return v.d_ < 0 ? "-Infinity" : "Infinity";
            return num(v.d_) + "_" + (v.width_ == 2 ? "1" : v.width_ == 4 ? "2" : "3");
        case Type::Bytes: {
            static const char* hex = "0123456789abcdef";
            s = "h'";
            for (uint8_t b : v.raw_) { s += hex[b >> 4]; s += hex[b & 15]; }
            return s + "'";
        }
        case Type::Text: return "\"" + v.s_ + "\"";
        case Type::Array:
            s = "[";
            for (size_t i = 0; i < v.kids_.size(); ++i) s += (i ? ", " : "") + diag(v.kids_[i]);
            return s + "]";
        case Type::Map:
            s = "{";
            for (size_t i = 0; i < v.map_.size(); ++i)
                s += (i ? ", " : "") + diag(v.map_[i].first) + ": " + diag(v.map_[i].second);
            return s + "}";
        case Type::Tagged: return std::to_string(v.u_) + "(" + diag(v.kids_[0]) + ")";
        case Type::Simple: return "simple(" + std::to_string(v.u_) + ")";
        case Type::Typed: case Type::NDArray: {
            s = std::string(elem_name(v.elem_));
            if (v.t_ == Type::NDArray) {
                s += "[";
                for (size_t i = 0; i < v.dims_.size(); ++i)
                    s += (i ? "x" : "") + std::to_string(v.dims_[i]);
                s += v.rowmajor_ ? " row-major]" : "]";
            }
            s += "[";
            for (size_t k = 0; k < v.count(); ++k) {
                if (k) s += ", ";
                if (k == 16) { s += "... (" + std::to_string(v.count()) + ")"; break; }
                s += (v.elem_ == Elem::f32 || v.elem_ == Elem::f64) ? num(v.elem_as_double(k))
                                                                    : v.elem_int_string(k);
            }
            return s + "]";
        }
    }
    return "?";
}


// ---------------------------------------------------------------------------
// Structs <-> CBOR maps (C++17, no macros required)
//
// Describe a struct once, as a table of (key, member pointer), in a free
// function cbor_fields(const T*) next to the struct (same namespace -- found
// by argument-dependent lookup):
//
//   struct Sample { uint32_t id; std::string name; float temperature; };
//   inline auto cbor_fields(const Sample*) {
//       return std::make_tuple(cbor::field("id",   &Sample::id),
//                              cbor::field("name", &Sample::name),
//                              cbor::field("temp", &Sample::temperature));
//   }
//   // or, key = member name:   CBOR_FIELDS(Sample, id, name, temperature)
//
//   cbor::Value v = cbor::to_value(s);              // -> map {"id":..,"name":..,"temp":..}
//   Sample s2     = cbor::from_value<Sample>(v);    // checked, see below
//
// Member types handled (recursively):
//   bool, integers, float, double      -> as Value(x); read back with as<T>() (range-checked)
//   enum                               -> its underlying integer
//   std::string                        -> text
//   std::vector<uint8_t>               -> byte string
//   std::vector<T> / std::array<T,N>, T numeric -> RFC 8746 typed array (exact element
//                                         type on read; a plain CBOR array of numbers is
//                                         also accepted, element by element, checked)
//   std::vector<T> / std::array<T,N>, other T   -> CBOR array
//   std::optional<T>                   -> key omitted when empty; missing key or null -> nullopt
//   any struct with cbor_fields        -> nested map
//   cbor::Value                        -> passed through as is
// Reading: unknown keys are ignored (forward compatible); a missing key for a
// non-optional member, a wrong CBOR type or an out-of-range number throws
// cbor::error ("range"/"type") whose message names the path, e.g.
// "cbor:range: raw[2]: 70000 does not fit int16". std::array needs exactly N
// elements. The struct must be default-constructible.

template <class C, class M>
struct field_t {
    const char* key;
    M C::*member;
};
template <class C, class M>
constexpr field_t<C, M> field(const char* key, M C::*member) { return {key, member}; }

namespace detail {

template <class T> struct is_vector : std::false_type {};
template <class T, class A> struct is_vector<std::vector<T, A>> : std::true_type {};
template <class T> struct is_std_array : std::false_type {};
template <class T, size_t N> struct is_std_array<std::array<T, N>> : std::true_type {};
template <class T> struct is_optional : std::false_type {};
template <class T> struct is_optional<std::optional<T>> : std::true_type {};

// ADL probe: does cbor_fields(const T*) exist?
template <class T, class = void> struct has_fields : std::false_type {};
template <class T>
struct has_fields<T, std::void_t<decltype(cbor_fields(static_cast<const T*>(nullptr)))>>
    : std::true_type {};

[[noreturn]] inline void rethrow_at(const error& e, const std::string& where) {
    std::string msg = e.what();
    const std::string head = "cbor:" + e.id + ": ";
    if (msg.compare(0, head.size(), head) == 0) msg.erase(0, head.size());
    const bool nested = !msg.empty() && (msg[0] == '[' || msg[0] == '.');
    throw error(e.id, where + (nested ? "" : ": ") + msg);
}

}  // namespace detail

template <class T> Value to_value(const T& x);
template <class T> T from_value(const Value& v);

namespace detail {

template <class T>
Value to_value_impl(const T& x) {
    if constexpr (std::is_same_v<T, Value>) {
        return x;
    } else if constexpr (has_fields<T>::value) {
        Value m = Value::map({});
        std::apply([&](const auto&... f) {
            auto put = [&](const auto& fd) {
                const auto& mem = x.*(fd.member);
                using M = std::decay_t<decltype(mem)>;
                if constexpr (is_optional<M>::value) {
                    if (mem) m.set(fd.key, to_value(*mem));
                } else {
                    m.set(fd.key, to_value(mem));
                }
            };
            (put(f), ...);
        }, cbor_fields(static_cast<const T*>(nullptr)));
        return m;
    } else if constexpr (std::is_enum_v<T>) {
        return Value(static_cast<std::underlying_type_t<T>>(x));
    } else if constexpr (std::is_arithmetic_v<T>) {
        return Value(x);
    } else if constexpr (std::is_same_v<T, std::string>) {
        return Value(x);
    } else if constexpr (std::is_same_v<T, std::vector<uint8_t>>) {
        return Value(x);
    } else if constexpr (is_vector<T>::value || is_std_array<T>::value) {
        using E = typename T::value_type;
        if constexpr (is_typed_elem_v<E>) {
            return Value::typed(x.data(), x.size());
        } else {
            Value::Array a;
            a.reserve(x.size());
            for (const auto& e : x) a.push_back(to_value(e));
            return Value(std::move(a));
        }
    } else if constexpr (is_optional<T>::value) {
        return x ? to_value(*x) : Value();
    } else {
        static_assert(sizeof(T) == 0,
                      "cbor::to_value: unsupported type -- give it cbor_fields(const T*) or CBOR_FIELDS");
    }
}

// numeric sequence from a typed array (exact element type) or a plain array (checked per element)
template <class E, class Out>
void numbers_into(const Value& v, Out& out, size_t n_fixed) {
    if (v.is_typed()) {
        std::vector<E> d = v.typed<E>();
        if (n_fixed && d.size() != n_fixed)
            throw error("range", std::to_string(d.size()) + " elements, expected " + std::to_string(n_fixed));
        if constexpr (is_vector<Out>::value) out.assign(d.begin(), d.end());
        else std::copy(d.begin(), d.end(), out.begin());
        return;
    }
    const auto& a = v.as_array();
    if (n_fixed && a.size() != n_fixed)
        throw error("range", std::to_string(a.size()) + " elements, expected " + std::to_string(n_fixed));
    if constexpr (is_vector<Out>::value) out.resize(a.size());
    for (size_t k = 0; k < a.size(); ++k) {
        try { out[k] = a[k].as<E>(); }
        catch (const error& e) { rethrow_at(e, "[" + std::to_string(k) + "]"); }
    }
}

template <class T>
T from_value_impl(const Value& v) {
    if constexpr (std::is_same_v<T, Value>) {
        return v;
    } else if constexpr (has_fields<T>::value) {
        static_assert(std::is_default_constructible_v<T>, "cbor::from_value: struct must be default-constructible");
        T x{};
        if (!v.is_map()) throw error("type", std::string("expected map, got ") + type_name(v.type()));
        std::apply([&](const auto&... f) {
            auto get = [&](const auto& fd) {
                auto& mem = x.*(fd.member);
                using M = std::decay_t<decltype(mem)>;
                const Value* item = v.find(fd.key);
                try {
                    if constexpr (is_optional<M>::value) {
                        if (item && !item->is_null()) mem = from_value<typename M::value_type>(*item);
                        else mem.reset();
                    } else {
                        if (!item) throw error("range", "missing key");
                        mem = from_value<M>(*item);
                    }
                } catch (const error& e) {
                    rethrow_at(e, std::string(".") + fd.key);
                }
            };
            (get(f), ...);
        }, cbor_fields(static_cast<const T*>(nullptr)));
        return x;
    } else if constexpr (std::is_enum_v<T>) {
        return static_cast<T>(v.as<std::underlying_type_t<T>>());
    } else if constexpr (std::is_arithmetic_v<T> || std::is_same_v<T, std::string>) {
        return v.as<T>();
    } else if constexpr (std::is_same_v<T, std::vector<uint8_t>>) {
        if (v.is_bytes()) return v.as_bytes();
        T out;
        numbers_into<uint8_t>(v, out, 0);
        return out;
    } else if constexpr (is_vector<T>::value || is_std_array<T>::value) {
        using E = typename T::value_type;
        T out{};
        size_t n_fixed = 0;
        if constexpr (is_std_array<T>::value) n_fixed = std::tuple_size_v<T>;
        if constexpr (is_typed_elem_v<E>) {
            numbers_into<E>(v, out, n_fixed);
        } else {
            const auto& a = v.as_array();
            if (n_fixed && a.size() != n_fixed)
                throw error("range", std::to_string(a.size()) + " elements, expected " + std::to_string(n_fixed));
            if constexpr (is_vector<T>::value) out.resize(a.size());
            for (size_t k = 0; k < a.size(); ++k) {
                try { out[k] = from_value<E>(a[k]); }
                catch (const error& e) { rethrow_at(e, "[" + std::to_string(k) + "]"); }
            }
        }
        return out;
    } else if constexpr (is_optional<T>::value) {
        if (v.is_null()) return std::nullopt;
        return from_value<typename T::value_type>(v);
    } else {
        static_assert(sizeof(T) == 0,
                      "cbor::from_value: unsupported type -- give it cbor_fields(const T*) or CBOR_FIELDS");
    }
}

}  // namespace detail

// C++ value -> generic Value (structs with cbor_fields become maps)
template <class T> Value to_value(const T& x) { return detail::to_value_impl<T>(x); }
// generic Value -> C++ value, checked (throws cbor::error with the failing path)
template <class T> T from_value(const Value& v) { return detail::from_value_impl<T>(v); }

}  // namespace cbor


// CBOR_FIELDS(Type, member, ...): defines cbor_fields(const Type*) with key = member name.
// Put it next to the struct, in the struct's namespace (or global scope). Up to 32 members.
#define CBOR_DETAIL_EXPAND(x) x
#define CBOR_DETAIL_F(T, m) ::cbor::field(#m, &T::m)
#define CBOR_DETAIL_FE_1(T, m) CBOR_DETAIL_F(T, m)
#define CBOR_DETAIL_FE_2(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_1(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_3(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_2(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_4(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_3(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_5(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_4(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_6(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_5(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_7(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_6(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_8(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_7(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_9(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_8(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_10(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_9(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_11(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_10(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_12(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_11(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_13(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_12(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_14(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_13(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_15(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_14(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_16(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_15(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_17(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_16(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_18(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_17(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_19(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_18(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_20(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_19(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_21(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_20(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_22(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_21(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_23(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_22(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_24(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_23(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_25(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_24(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_26(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_25(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_27(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_26(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_28(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_27(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_29(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_28(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_30(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_29(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_31(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_30(T, __VA_ARGS__))
#define CBOR_DETAIL_FE_32(T, m, ...) CBOR_DETAIL_F(T, m), CBOR_DETAIL_EXPAND(CBOR_DETAIL_FE_31(T, __VA_ARGS__))
#define CBOR_DETAIL_NARG_(_0, _1, _2, _3, _4, _5, _6, _7, _8, _9, _10, _11, _12, _13, _14, _15, _16, _17, _18, _19, _20, _21, _22, _23, _24, _25, _26, _27, _28, _29, _30, _31, _32, N, ...) N
#define CBOR_DETAIL_NARG(...) CBOR_DETAIL_EXPAND(CBOR_DETAIL_NARG_(__VA_ARGS__, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0))
#define CBOR_DETAIL_CAT_(a, b) a##b
#define CBOR_DETAIL_CAT(a, b) CBOR_DETAIL_CAT_(a, b)
#define CBOR_FIELDS(Type, ...)                                                        \
    [[maybe_unused]] inline auto cbor_fields(const Type*) {                            \
        return std::make_tuple(CBOR_DETAIL_EXPAND(CBOR_DETAIL_CAT(CBOR_DETAIL_FE_,      \
            CBOR_DETAIL_NARG(Type, __VA_ARGS__))(Type, __VA_ARGS__)));                \
    }

#endif  // CBOR_HPP_INCLUDED
