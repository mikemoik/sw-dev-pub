# cbor

CBOR codec twins for compact sensor/logger streams: the same RFC 8949 subset in **C++17** (single header) and **MATLAB/Octave**, plus RFC 8746 typed arrays — so a stream written on one side reads on the other. Python scripts cross-check against the independent `cbor2` decoder and compare stream encodings against JSON.

**Owner:** swdevos · **Status:** stable, tested (C++ 184 assertions, Octave 121 checks) · **License:** MIT (repo root)

## Files

| File | What |
|---|---|
| `cbor.hpp` | C++17 single header: `cbor::Writer`, `cbor::Value`, `cbor::Reader`; typed arrays (little-endian), tag 1040 matrices, tag 55799 self-describe header. No dependencies. |
| `cborenc.m` / `cbordec.m` | MATLAB/Octave encoder (literal class → major-type mapping) and generic decoder (indefinite lengths, chunked strings, typed arrays, CBOR sequences). |
| `cbor_test.cpp` / `cbor_test.m` | Test suites; `cbor_test --write/--read FILE` for interop. |
| `cbor_interop_check.py` | Cross-check streams against Python `cbor2`. |
| `cbor_stream_sizes.py` | How big is a logger stream under different record encodings vs JSON (no deps). |
| `CBOR_CHEATSHEET.md` | Usage, type mapping, stream layout, gotchas. Start here. |

## Build & test (from this directory)

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

C++: copy `cbor.hpp` into your project (or add this dir to the include path) and `#include "cbor.hpp"`. MATLAB: put this dir on the path (`addpath`). Details in `CBOR_CHEATSHEET.md`.
