# cbor

CBOR codec twins for compact sensor/logger streams: the same RFC 8949 subset in **C++17** (single header) and **MATLAB/Octave**, plus RFC 8746 typed arrays — so a stream written on one side reads on the other. Python scripts cross-check against the independent `cbor2` decoder and compare stream encodings against JSON.

**Owner:** swdevos · **Status:** stable, tested (C++ 184 assertions, Octave 121 checks) · **License:** MIT (repo root)

## Files

| File | What |
|---|---|
| `CMakeLists.txt`, `CMakePresets.json`, `cmake/` | CMake build: header-only target `cbor::cbor`, CTest suite, install + `find_package(cbor)` package config. |
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

CTest runs `cbor.unit` (the 184-assertion suite) and a C++ write → read stream round trip. If the configured Python 3 can `import cbor2`, three interop tests against cbor2 are added (C++ → cbor2, cbor2 → C++); point CMake at the venv with `-DPython3_EXECUTABLE=$PWD/.venv/bin/python` (see below).

Options (default `ON` when this is the top-level project, `OFF` when pulled in by a consumer): `CBOR_BUILD_TESTS`, `CBOR_INSTALL`.

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

### MATLAB / Octave

Put this dir on the path (`addpath`). Details in `CBOR_CHEATSHEET.md`.
