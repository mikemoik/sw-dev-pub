# cbor

CBOR codec twins for compact sensor/logger streams: the same RFC 8949 subset in **C++17** (single header) and **MATLAB/Octave**, plus RFC 8746 typed arrays — so a stream written on one side reads on the other. Python scripts cross-check against the independent `cbor2` decoder and compare stream encodings against JSON.

**Owner:** swdevos · **Status:** stable, tested (C++ 215 assertions, Octave 121 checks) · **Version:** 1.1.0 (C++17) · **License:** MIT (repo root)

## Files

| File | What |
|---|---|
| `CMakeLists.txt`, `CMakePresets.json`, `cmake/` | CMake build: header-only target `cbor::cbor`, CTest suite, install + `find_package(cbor)` package config. |
| `examples/struct_roundtrip/` | Minimal consumer: struct → CBOR → struct, own `CMakeLists.txt` (`find_package(cbor)`); run by CTest. |
| `cbor.hpp` | C++17 single header: `cbor::Writer`, `cbor::Value`, `cbor::Reader`; typed arrays (little-endian), tag 1040 matrices, tag 55799 self-describe header. No dependencies. |
| `cborenc.m` / `cbordec.m` | MATLAB/Octave encoder (literal class → major-type mapping) and generic decoder (indefinite lengths, chunked strings, typed arrays, CBOR sequences). |
| `cbor_test.cpp` / `cbor_test.m` | Test suites; `cbor_test --write/--read FILE` for interop. |
| `cbor_interop_check.py` | Cross-check streams against Python `cbor2`. |
| `cbor_stream_sizes.py` | How big is a logger stream under different record encodings vs JSON (no deps). |
| `CBOR_CHEATSHEET.md` | Usage, type mapping, stream layout, gotchas. Start here. |

## Build & test (from this directory)

### C++ with CMake (≥ 3.21)

```sh
cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# or without presets:
cmake -S . -B build && cmake --build build && ctest --test-dir build
```

CTest runs `cbor.unit` (the 215-assertion suite), a C++ write → read stream round trip and the `struct_roundtrip` example. If the configured Python 3 can `import cbor2`, three interop tests against cbor2 are added (C++ → cbor2, cbor2 → C++); point CMake at the venv with `-DPython3_EXECUTABLE=$PWD/.venv/bin/python` (see below).

Options (default `ON` when this is the top-level project, `OFF` when pulled in by a consumer): `CBOR_BUILD_TESTS`, `CBOR_BUILD_EXAMPLES`, `CBOR_INSTALL`.

### Without CMake

```sh
# C++ (g++ or clang++, C++17)
g++ -std=c++17 -Wall -Wextra -pedantic -O1 -o /tmp/cbor_test cbor_test.cpp && /tmp/cbor_test

# MATLAB or Octave
octave --eval cbor_test          # MATLAB: >> cbor_test

# Stream size comparison (Python 3, stdlib only)
python3 cbor_stream_sizes.py

# Interop with cbor2 (venv in .venv/, gitignored)
uv venv .venv && uv pip install -p .venv/bin/python cbor2     # or: python3 -m venv .venv && .venv/bin/pip install cbor2
/tmp/cbor_test --write cpp.cbor && .venv/bin/python cbor_interop_check.py read cpp.cbor
.venv/bin/python cbor_interop_check.py write py.cbor && /tmp/cbor_test --read py.cbor
```

## Use

### C++

Link the target `cbor::cbor` (header-only, sets C++17) and `#include "cbor.hpp"`. Three ways to get it:

```cmake
# 1. vendored copy / git submodule
add_subdirectory(third_party/cbor)

# 2. FetchContent (straight from this repo)
include(FetchContent)
FetchContent_Declare(cbor
    GIT_REPOSITORY https://github.com/mikemoik/sw-dev-pub.git
    GIT_TAG        main            # pin a commit for reproducible builds
    SOURCE_SUBDIR  projects/cbor)
FetchContent_MakeAvailable(cbor)

# 2b. FetchContent without git (plain HTTPS download, pinned + hash-checked)
FetchContent_Declare(cbor
    URL      https://github.com/mikemoik/sw-dev-pub/releases/download/cbor-v1.0.0/cbor-1.0.0.tar.gz
    URL_HASH SHA256=<from cbor-1.0.0.tar.gz.sha256>
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
#    or the whole-repo archive of a commit:  URL https://github.com/mikemoik/sw-dev-pub/archive/<sha>.tar.gz
#    plus  SOURCE_SUBDIR projects/cbor
FetchContent_MakeAvailable(cbor)

# 3. installed package:  cmake --install build --prefix <prefix>,  then
find_package(cbor 1.0 REQUIRED CONFIG)   # CMAKE_PREFIX_PATH=<prefix>

target_link_libraries(app PRIVATE cbor::cbor)
```

Or skip CMake entirely: copy `cbor.hpp` into your tree.

### Quickstart: install, then serialize a struct

```sh
# from a release tarball (or this directory of a checkout)
curl -fLO https://github.com/mikemoik/sw-dev-pub/releases/download/cbor-v<version>/cbor-<version>.tar.gz
tar xzf cbor-<version>.tar.gz && cd cbor
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build && ctest --test-dir build
cmake --install build --prefix $HOME/.local      # include/cbor.hpp + share/cmake/cbor/

# build the example against the installed package
cmake -S examples/struct_roundtrip -B /tmp/demo -DCMAKE_PREFIX_PATH=$HOME/.local
cmake --build /tmp/demo && /tmp/demo/struct_roundtrip
```

The core of [`examples/struct_roundtrip/main.cpp`](examples/struct_roundtrip/main.cpp):

```cpp
struct Sample { uint32_t id; std::string name; float temperature; std::vector<int16_t> raw; };
CBOR_FIELDS(Sample, id, name, temperature, raw)          // once, next to the struct

std::vector<uint8_t> bytes = cbor::encode(cbor::to_value(in));      // serialize
Sample out = cbor::from_value<Sample>(cbor::decode(bytes));         // deserialize, checked
```

`cbor::diag(cbor::decode(bytes))` prints `{"id": 42, "name": "imu0", "temperature": 21.5_2, "raw": i16[-3, 0, 7, 1024]}` (48 bytes). `_2` is RFC 8949's marker for float32 (`_1` float16, `_3` float64).

### Structs ↔ CBOR (since 1.1.0)

Describe a struct once; `cbor::to_value(x)` turns it into a map, `cbor::from_value<T>(v)` reads it back **checked**.

```cpp
namespace app {
struct Pos { double x, y; };
CBOR_FIELDS(Pos, x, y)                                   // key = member name, up to 32 members

struct Sample { uint32_t id; float temperature; std::optional<std::string> note;
                std::array<float, 3> acc; std::vector<Pos> path; };
inline auto cbor_fields(const Sample*) {                 // or by hand: own keys, no macro
    return std::make_tuple(cbor::field("id", &Sample::id), cbor::field("temp", &Sample::temperature),
                           cbor::field("note", &Sample::note), cbor::field("acc", &Sample::acc),
                           cbor::field("path", &Sample::path));
}
}  // namespace app   -- both forms live next to the struct, in its namespace (found by ADL)
```

| Member type | On the wire | Read back |
|---|---|---|
| `bool`, integers, `float`, `double` | int / float32 / float64 | `as<T>()`: integers range-checked, a float into an integer is a type error, any number into a float |
| `enum` | its underlying integer | range-checked |
| `std::string` / `std::vector<uint8_t>` | text / byte string | exact (bytes also from an array of small ints) |
| `std::vector<T>`, `std::array<T,N>`, numeric `T` | RFC 8746 typed array | exact element type, or a plain CBOR array checked per element; `std::array` needs exactly N |
| containers of other `T` | CBOR array | per element |
| `std::optional<T>` | key omitted when empty | missing key or null → `nullopt` |
| struct with `cbor_fields` / `CBOR_FIELDS` | nested map | recursively |
| `cbor::Value` | as is | as is |

Unknown keys are ignored, so old readers accept newer data. A missing key for a non-optional member, a wrong type or a value that doesn't fit throws `cbor::error` with the path: `cbor:range: .path[0].x: …`, `cbor:range: .id: 5000000000 does not fit uint32`. Structs must be default-constructible. `as<T>()` also works on any `cbor::Value`: `v["id"].as<uint32_t>()`.

### MATLAB / Octave

Put this dir on the path (`addpath`). Details in `CBOR_CHEATSHEET.md`.
