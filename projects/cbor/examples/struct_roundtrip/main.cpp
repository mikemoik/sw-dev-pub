// struct_roundtrip — serialize a struct to CBOR bytes and back (cbor::cbor, C++17).
//
// Describe the struct once with CBOR_FIELDS; cbor::to_value / cbor::from_value
// do both directions. The struct becomes a CBOR map keyed by member name, so
// member order does not matter and new members don't break old readers.
// Reading is checked: a value that does not fit the member type, a wrong type
// or a missing key throws cbor::error naming the member (e.g. ".id: ...").
//
// Expected output:
//   48 bytes: {"id": 42, "name": "imu0", "temperature": 21.5_2, "raw": i16[-3, 0, 7, 1024]}
//   id=42 name=imu0 temperature=21.5 raw[3]=1024
// In diag output the float suffix is the RFC 8949 encoding indicator:
// _1 = float16, _2 = float32, _3 = float64 — so 21.5_2 is the float member as float32.
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
CBOR_FIELDS(Sample, id, name, temperature, raw)

int main() {
    Sample in{42, "imu0", 21.5f, {-3, 0, 7, 1024}};

    std::vector<uint8_t> bytes = cbor::encode(cbor::to_value(in));         // serialize
    Sample out = cbor::from_value<Sample>(cbor::decode(bytes));            // deserialize

    std::printf("%zu bytes: %s\n", bytes.size(), cbor::diag(cbor::decode(bytes)).c_str());
    std::printf("id=%u name=%s temperature=%.1f raw[3]=%d\n",
                out.id, out.name.c_str(), out.temperature, out.raw[3]);
    return (out.id == in.id && out.name == in.name &&
            out.temperature == in.temperature && out.raw == in.raw) ? 0 : 1;
}
