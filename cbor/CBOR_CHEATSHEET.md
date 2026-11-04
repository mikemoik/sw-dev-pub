# CBOR codecs — cheatsheet (MATLAB + C++)

`cborenc.m` / `cbordec.m` — RFC 8949 subset encoder + generic
decoder, with RFC 8746 typed arrays. No toolboxes, no MEX. Status: **verified**
(2026-09-04, Octave 11.3): `cbor_test` passes 119/119, and a two-way interop
check against Python `cbor2` (header + typed-array blocks + tag 1040 matrix,
both write→read directions) passed. Only the `undefined`→`missing` mapping is
untested (Octave lacks `missing`); confirm once under real MATLAB.

Companion: `cbor.hpp` — the same codec in C++17, single header, no
dependencies. Same wire conventions, so MATLAB and C++ read each other's files
byte-for-byte; see the **C++** section at the end.

## Quick start (MATLAB)

```matlab
b = cborenc(struct('v', uint8(1), 'name', 'imu0'));   % -> uint8 row vector
[v, pos] = cbordec(b);                                % v is the struct again
```

Streaming file (CBOR sequence, RFC 8742 — items back to back, no container):

```matlab
% write
fid = fopen('log.cbor', 'w');
fwrite(fid, cborenc(struct('cbor_tag', 55799, 'value', header)), 'uint8');
fwrite(fid, cborenc({uint32(t), single(ax), single(ay), single(az)}), 'uint8');
fclose(fid);

% read
b = fread(fopen('log.cbor', 'r'), Inf, '*uint8')';
[header, pos] = cbordec(b);            % tag 55799 unwraps automatically
while pos <= numel(b)
    [blk, pos] = cbordec(b, pos);      % {uint32 row, single row, ...}
end
```

## Encoding: MATLAB → CBOR

The MATLAB **class decides the wire type**. Nothing is guessed: `1000` is a
double and costs 9 bytes; `uint16(1000)` costs 3. Cast on purpose.

| MATLAB value | CBOR encoding | Size |
|---|---|---|
| `[]` (any empty numeric) | null `f6` | 1 B |
| `true` / `false` (scalar) | `f5` / `f4` | 1 B |
| `uint8..uint64` scalar | unsigned int (major 0) | 1–9 B, shortest form |
| `int8..int64` scalar | neg int (major 1) if < 0 | 1–9 B, shortest form |
| `single` scalar | float32 `fa` | 5 B |
| `double` scalar | float64 `fb` | 9 B |
| `struct('cbor_f16', x)` | float16 `f9`, round-to-nearest-even | 3 B |
| `'text'` / `"text"` scalar | text string (major 3, UTF-8) | 1–3 B head + bytes |
| `uint8` row vector | byte string (major 2) | 1–5 B head + N |
| other numeric vector | **typed array**: LE tag + packed byte string | ~5 B + N·width |
| numeric matrix / ND | tag 1040 (column-major) + dims + typed array | above + ~4 B |
| logical vector | array of `f4`/`f5` items | 1 B/element |
| cell array | array (major 4), per-element types | 1–5 B head + items |
| scalar struct | map (major 5), field names as text keys | keys + values |
| `containers.Map` / `dictionary` | map | keys + values |
| `struct('cbor_tag', n, 'value', x)` | tag n (major 6) + item — any tag by hand | 1–9 B + item |

Typed-array tags emitted (always little-endian = raw `typecast` on x86/ARM):

| Class | Tag | | Class | Tag |
|---|---|---|---|---|
| `uint8`* | 64 | | `int8` | 72 |
| `uint16` | 69 | | `int16` | 77 |
| `uint32` | 70 | | `int32` | 78 |
| `uint64` | 71 | | `int64` | 79 |
| `single` | 85 | | `double` | 86 |

\* a `uint8` **vector** encodes as a plain byte string instead (idiomatic CBOR);
tag 64 appears only inside matrices.

Escape hatches:
- per-item array instead of typed array → `num2cell(v)`
- any semantic tag → `struct('cbor_tag', n, 'value', x)`
- indefinite-length containers → emit `uint8(159)`/`uint8(191)` (array/map
  open) and `uint8(255)` (break) yourself around `cborenc` calls

## Decoding: CBOR → MATLAB

`cbordec` is a **generic** decoder — it reads any well-formed item, including
things `cborenc` never produces (indefinite lengths, chunked strings, BE
typed arrays, all integer widths).

| CBOR item | MATLAB result |
|---|---|
| int, \|n\| < 2⁵³ | `double` |
| int beyond 2⁵³ | `uint64` / `int64` (errors below intmin int64) |
| byte string | `uint8` row |
| text string | `char` row (UTF-8 decoded) |
| array | cell row |
| map, all keys valid identifiers | `struct` (field order preserved) |
| map, other char keys / numeric keys | `containers.Map` |
| float16 / float64 | `double` |
| float32 | `single` |
| `false` / `true` | `logical` |
| null | `[]` |
| undefined | `missing` |
| other simple value | `struct('cbor_simple', n)` |
| tag 55799 (self-describe) | unwrapped silently |
| tags 64–87 (typed array, both endiannesses) | typed row vector; float16→double |
| tag 40 / 1040 (multi-dim) | MATLAB array (40 row-major, 1040 column-major) |
| any other tag | `struct('cbor_tag', n, 'value', content)` |

## Logger file layout (the convention, not part of CBOR)

```
d9 d9 f7                magic: tag 55799 wrapping the header
<map>                   header: v, t0, dt_ms, fields, units, blocksize, ...
<array>                 block 1: one typed array per field, column order = header.fields
<array>                 block 2 ...
                        EOF ends the stream -- no terminator, crash-safe
```

- Reader rule: top-level **map = (new) header**, **array = record block**.
  This permits mid-stream re-headers on schema/session change.
- With fixed block size B and fixed element widths, every block has identical
  byte length → **O(1) seek** to block `floor(k/B)` by arithmetic. Store the
  block byte size in the header.
- A truncated final block is lost as a unit; everything before it stays valid.

## Gotchas

1. **Bare numbers are doubles.** `struct('n', 5)` writes a 9-byte float.
   Cast every integer field: `uint32(5)`.
2. **Column vectors come back as rows.** Typed-array payloads are flat; only
   the ND path (tag 1040) preserves shape.
3. **Empty numeric `[]` encodes as null**, not as an empty array/string.
   Zero-length typed columns are not representable — don't write empty blocks.
4. **null and `[]` collapse.** MATLAB has no null; round trip cannot tell
   them apart.
5. **`uint8` scalar vs vector**: scalar → integer, vector → byte string.
   `uint8` 1-element "arrays" are indistinguishable from scalars.
6. **Struct arrays don't encode** — only scalar structs. Use a cell of structs.
7. **Map key order is preserved, not sorted** — output is not deterministic
   encoding (RFC 8949 §4.2); don't hash/sign it without sorting fields first.
8. **No datetime/duration/string-array support** — convert to numbers/char
   before encoding. Semantic tags for dates (0/1) are available via `cbor_tag`.
9. **`cbordec` needs the whole buffer in memory** — for huge files, `fread`
   block-sized slices and decode with the two-output loop per slice, or seek
   by fixed block stride.
10. **NaN**: scalar floats encode the canonical quiet NaN (`f97e00` /
    `fa7fc00000` / `fb7ff8...`) on every host — MATLAB's native NaN has the
    sign bit set and must not leak. Inside typed arrays, NaN bytes are raw
    memory and DO differ between MATLAB and Octave writers; they decode to
    NaN everywhere, but don't byte-compare/hash files across hosts.

## Interop check (do this once)

Python: `pip install cbor2`, then

```python
import cbor2, numpy as np
items = []
with open('log.cbor', 'rb') as f:
    while True:
        try: items.append(cbor2.load(f))
        except (EOFError, cbor2.CBORDecodeEOF): break
hdr, blocks = items[0], items[1:]           # hdr: dict-like (frozendict)
t  = np.frombuffer(blocks[0][0].value, '<u4')   # CBORTag(70, bytes) -> .value
ax = np.frombuffer(blocks[0][1].value, '<f4')   # CBORTag(85, bytes)
```

Or paste hex of a small file into https://cbor.me (knows tags 64–87 by number).
This exact check (plus the reverse direction, cbor2 → cbordec) passed on
2026-09-04.

## Test suite

`cbor_test.m` — run `cbor_test` from this directory. ~120
assertions: RFC 8949 Appendix A vectors, float16 edge cases (ties-to-even,
subnormals, overflow→Inf), typed arrays in both byte orders and all classes,
multi-dim tags 40/1040, indefinite lengths and chunked strings, >2^53
integers, unknown-tag passthrough, non-identifier map keys, seven
malformed-input error cases, and a full header+blocks streaming round trip.
Prints a summary; errors if anything failed.

## C++ — `cbor.hpp`

Status: **verified** (2026-09-10): `cbor_test.cpp` passes 184/184 under GCC 16.1
and clang (C++17, `-Wall -Wextra -pedantic`, ASan+UBSan), and the three-way
interop passed: C++ → cbor2, cbor2 → C++ (LE + BE typed arrays, tag 1040
matrix, float16 array), C++ → Octave `cbordec`, cbor2 → Octave.

```sh
g++ -std=c++17 -O2 -o /tmp/cbor_test cbor_test.cpp && /tmp/cbor_test
```

### Three layers

| Layer | What it is | Use when |
|---|---|---|
| `cbor::Writer` | appends heads/items/typed arrays to `std::vector<uint8_t> buf` | logging: one `w.array(2).typed(t).typed(ax)` per block, no allocations besides the buffer |
| `cbor::Value` | generic tree: null/undefined/bool/int/float/bytes/text/array/map/tagged/simple/typed/ndarray | headers, config, anything you build or inspect by key |
| `cbor::Reader` | `Reader r(buf); while (!r.done()) Value v = r.next();` | reading a CBOR sequence (RFC 8742) |

Free functions: `encode(Value) -> bytes`, `decode(bytes[, pos&])`, `decode_all(bytes)`,
`diag(Value)` (RFC 8949 diagnostic notation, floats suffixed `_1/_2/_3` for
f16/f32/f64, typed arrays as `u32[1, 2]`, ND as `f32[2x3][...]`).

### Encoding: C++ → CBOR (the C++ type decides, nothing is guessed)

| C++ value | CBOR | MATLAB twin |
|---|---|---|
| `nullptr` / `Value()` | null `f6` | `[]` |
| `bool` | `f4`/`f5` | logical |
| any integer type | major 0/1, shortest head | `intN`/`uintN` scalar |
| `float` | float32 `fa` | `single` |
| `double` | float64 `fb` | `double` |
| `cbor::f16{x}` | float16 `f9`, ties-to-even | `struct('cbor_f16', x)` |
| `const char*`, `std::string`, `string_view` | text (UTF-8 passed through, not validated) | char |
| `std::vector<uint8_t>` | byte string | `uint8` row |
| `std::vector<T>` numeric (T ≠ uint8) | typed array, LE tag + bytes | numeric vector |
| `Value::typed<uint8_t>(v)` | typed array tag 64 (explicit) | uint8 inside matrices |
| `Value::ndarray({r, c}, v)` | tag 1040 (column-major) `[[r, c], typed]` | matrix |
| `Value::ndarray(dims, v, /*row_major=*/true)` | tag 40 | — |
| `Value::array({...})`, `std::vector<Value>` | array | cell |
| `Value::map({{"k", v}, ...})` | map, insertion order | scalar struct |
| `Value::tagged(n, v)` | tag n | `cbor_tag` struct |
| `Value::simple(n)`, `Value::undefined()` | simple / `f7` | — |
| `Writer::array_indef()/map_indef()/brk()` | indefinite containers | raw `9f`/`bf`/`ff` |

Differences from the MATLAB encoder, on purpose:
- an **empty `std::vector<uint8_t>` is an empty byte string** (`40`), and an
  empty typed vector is an empty typed array (`d8 56 40`) — not null.
- `float` and `double` are distinct C++ types, so no "bare numbers are doubles"
  trap: `Value(5)` is an int (1 byte), `Value(5.0)` a float64 (9 bytes).
- NaN handling is identical: scalar NaN is canonicalised (`fa7fc00000`,
  `fb7ff8…`, `f97e00`); typed-array NaNs are raw memory.
- float16 rounding is done directly from the double (no intermediate float32).
  One consequence: values strictly between 2⁻²⁵ and 2⁻²⁴ round **up** to the
  smallest subnormal (`0001`) here, while `cborenc.m` flushes them to zero.
  Exact ties (2⁻²⁵ itself) go to even (zero) in both.

### Decoding: CBOR → `Value`

| CBOR | `Value` type | accessor |
|---|---|---|
| int in int64 range | `Int` | `as_int64()`, `as_uint64()`, `as_double()` |
| int > 2⁶³−1 | `Uint` | `as_uint64()`; `as_int64()` throws `range` |
| int < −2⁶³ | error `range` | (same as MATLAB) |
| float16/32/64 | `Float` with `float_width()` 2/4/8 | `as_double()`; width is part of equality |
| bytes / text | `Bytes` / `Text` | `as_bytes()`, `as_text()`, `size()` |
| array | `Array` | `v[i]`, `as_array()`, `size()` |
| map (any key types) | `Map` = vector of pairs, order kept | `v["key"]` (throws `range` if missing), `find("key")`, `contains()`, `as_map()` |
| tag 55799 | unwrapped | |
| tags 64–87 (LE and BE) | `Typed`, bytes byte-swapped to **host order** | `elem()`, `count()`, `typed<T>()` (copy, exact T), `data<T>()` (view), `to_doubles()` |
| float16 typed array | `Typed` f64 (widened) | |
| float128 typed array | `Tagged` passthrough | |
| tag 40 / 1040 | `NDArray` (typed + `dims()` + `row_major()`); plain-array data becomes f64 | same accessors as `Typed` |
| other tag | `Tagged` | `tag()`, `content()` |
| false/true/null/undefined | `Bool`/`Null`/`Undefined` | `as_bool()`, `is_null()` |
| other simple | `Simple` | `simple_value()` |

Malformed input throws `cbor::error` with `.id` ∈ {`eof`, `break`, `reserved`,
`chunk`, `typedarray`, `multidim`, `range`, `depth`}; wrong-type accessors throw
`type`. Nesting is capped at 512 (`Reader::max_depth`).

### Logger, C++ side

```cpp
#include "cbor.hpp"
using cbor::Value;

// write
cbor::Writer w;
w.value(Value::tagged(55799, Value::map({{"v", 1}, {"dev", "imu0"},
        {"t0", t0}, {"dt_ms", uint16_t(10)}, {"fields", Value::array({"t", "ax"})}})));
std::ofstream f("log.cbor", std::ios::binary);
f.write((const char*)w.buf.data(), w.buf.size()); w.clear();
for (;;) {                                 // per block
    w.array(2).typed(t_vec).typed(ax_vec); // std::vector<uint32_t>, std::vector<float>
    f.write((const char*)w.buf.data(), w.buf.size()); w.clear();
}

// read
std::ifstream in("log.cbor", std::ios::binary);
std::vector<uint8_t> b((std::istreambuf_iterator<char>(in)), {});
cbor::Reader r(b);
Value hdr = r.next();                      // tag 55799 already unwrapped
while (!r.done()) {
    Value blk = r.next();                  // array of Typed
    const uint32_t* t = blk[0].data<uint32_t>();
    std::vector<float> ax = blk[1].typed<float>();
}
```

Gotchas specific to C++:
1. `data<T>()` is a view into the `Value`'s buffer, host byte order, but **not
   guaranteed aligned** for T — fine on x86/ARM64, use `typed<T>()` on strict
   targets.
2. `typed<T>()` requires the exact element type (a `u32` array will not come
   back as `int32_t`); use `to_doubles()` for "just give me numbers".
3. `Value` equality is structural and treats NaN == NaN, but a float32 `1.0`
   is not equal to a float64 `1.0` (width is identity, as `single` vs `double`).
4. `Reader` works on a buffer in memory (like `cbordec`); for huge files read
   block-sized slices and construct a `Reader` per slice, or seek by fixed stride.

### Interop check

`cbor_interop_check.py` (needs `cbor2` in a venv):

```sh
/tmp/cbor_test --write cpp.cbor && python cbor_interop_check.py read cpp.cbor
python cbor_interop_check.py write py.cbor && /tmp/cbor_test --read py.cbor
```

The `read` side decodes any logger stream (MATLAB- or C++-written) with cbor2
and unpacks every typed column; the `write` side emits LE + BE blocks, a tag
1040 matrix and a float16 array for the other decoders to chew on.
