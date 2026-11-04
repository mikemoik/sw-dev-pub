// struct_roundtrip — serialize a struct to CBOR bytes and back (cbor::cbor, C++17).
//
// The struct becomes a CBOR map keyed by field name, so field order does not
// matter and new fields don't break old readers. Expected output:
//   41 bytes: {"id": 42, "name": "imu0", "temp": 21.5_2, "raw": i16[-3, 0, 7, 1024]}
//   id=42 name=imu0 temp=21.5 raw[3]=1024
// In diag output the float suffix is the RFC 8949 encoding indicator:
// _1 = float16, _2 = float32, _3 = float64 — so 21.5_2 is the float field as float32.
// Exit code 0 if the round trip reproduces the struct exactly.
#include "cbor.hpp"
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

struct Sample {
    uint32_t             id;
    std::string          name;
    float                temperature;
    std::vector<int16_t> raw;   // becomes an RFC 8746 typed array
};

std::vector<uint8_t> serialize(const Sample& s) {
    return cbor::encode(cbor::Value::map({
        {"id", s.id}, {"name", s.name}, {"temp", s.temperature}, {"raw", s.raw}}));
}

Sample deserialize(const std::vector<uint8_t>& bytes) {
    cbor::Value v = cbor::decode(bytes);   // throws cbor::error on bad input
    return Sample{
        static_cast<uint32_t>(v["id"].as_uint64()),
        v["name"].as_text(),
        static_cast<float>(v["temp"].as_double()),
        v["raw"].typed<int16_t>()};
}

int main() {
    Sample in{42, "imu0", 21.5f, {-3, 0, 7, 1024}};
    std::vector<uint8_t> bytes = serialize(in);
    Sample out = deserialize(bytes);

    std::printf("%zu bytes: %s\n", bytes.size(), cbor::diag(cbor::decode(bytes)).c_str());
    std::printf("id=%u name=%s temp=%.1f raw[3]=%d\n",
                out.id, out.name.c_str(), out.temperature, out.raw[3]);
    return (out.id == in.id && out.name == in.name &&
            out.temperature == in.temperature && out.raw == in.raw) ? 0 : 1;
}
