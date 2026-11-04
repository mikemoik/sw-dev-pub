"""How large is a CBOR sensor-log stream (header + N fixed records) under
different record encodings, versus JSON?

Answers: does encoding each record as a keyed map instead of a fixed-order
array actually cost meaningful bytes, and how much does dropping the
per-record timestamp (implied by t0 + dt in the header) save?

Self-contained: implements just enough of RFC 8949 to encode the shapes
under test, so it runs without cbor2 installed. No arguments.
"""

import json
import struct
import zlib

# --- minimal RFC 8949 encoder -------------------------------------------------

BREAK = b"\xff"


def _head(major: int, value: int) -> bytes:
    if value < 24:
        return bytes([major << 5 | value])
    if value < 0x100:
        return bytes([major << 5 | 24, value])
    if value < 0x10000:
        return bytes([major << 5 | 25]) + struct.pack(">H", value)
    if value < 0x100000000:
        return bytes([major << 5 | 26]) + struct.pack(">I", value)
    return bytes([major << 5 | 27]) + struct.pack(">Q", value)


def enc(obj, *, floats="f4") -> bytes:
    """Encode one CBOR data item. floats: 'f4' -> float32, 'f8' -> float64."""
    if obj is None:
        return b"\xf6"
    if obj is True:
        return b"\xf5"
    if obj is False:
        return b"\xf4"
    if isinstance(obj, int):
        return _head(0, obj) if obj >= 0 else _head(1, -1 - obj)
    if isinstance(obj, float):
        if floats == "f4":
            return b"\xfa" + struct.pack(">f", obj)
        return b"\xfb" + struct.pack(">d", obj)
    if isinstance(obj, str):
        raw = obj.encode()
        return _head(3, len(raw)) + raw
    if isinstance(obj, bytes):
        return _head(2, len(obj)) + obj
    if isinstance(obj, (list, tuple)):
        return _head(4, len(obj)) + b"".join(enc(x, floats=floats) for x in obj)
    if isinstance(obj, dict):
        out = _head(5, len(obj))
        for k, v in obj.items():
            out += enc(k, floats=floats) + enc(v, floats=floats)
        return out
    raise TypeError(type(obj))


def indefinite_array(items, *, floats="f4") -> bytes:
    return b"\x9f" + b"".join(enc(x, floats=floats) for x in items) + BREAK


SELF_DESCRIBE = b"\xd9\xd9\xf7"  # tag 55799, usable as a 3-byte file magic

# --- the workload -------------------------------------------------------------

RATE_HZ = 100
MINUTES = 10
N = RATE_HZ * 60 * MINUTES
FIELDS = ["t", "ax", "ay", "az"]


def records():
    """Synthetic IMU log: ms timestamp + 3 float accelerations."""
    for i in range(N):
        t = i * (1000 // RATE_HZ)
        yield t, 0.1 * i % 9.81, 0.2 * i % 9.81, 9.81 - (0.01 * i % 1.0)


def main() -> None:
    recs = list(records())
    header = {
        "v": 1,
        "dev": "imu0",
        "t0": 1756944000,
        "dt_ms": 1000 // RATE_HZ,
        "fields": FIELDS,
        "units": ["ms", "m/s2", "m/s2", "m/s2"],
    }

    variants = {}

    # A: newline-delimited JSON, keyed records
    variants["JSON lines (keyed)"] = (
        json.dumps(header, separators=(",", ":")).encode()
        + b"\n"
        + b"\n".join(
            json.dumps(dict(zip(FIELDS, r)), separators=(",", ":")).encode()
            for r in recs
        )
    )

    # B: CBOR sequence, each record a map with string keys
    variants["CBOR seq, map records"] = SELF_DESCRIBE + enc(header) + b"".join(
        enc(dict(zip(FIELDS, r))) for r in recs
    )

    # C: CBOR sequence, each record a fixed-order array (schema in header)
    variants["CBOR seq, array records"] = SELF_DESCRIBE + enc(header) + b"".join(
        enc(list(r)) for r in recs
    )

    # D: as C, but timestamp implied by index via header t0/dt
    variants["CBOR seq, no per-rec time"] = SELF_DESCRIBE + enc(header) + b"".join(
        enc(list(r[1:])) for r in recs
    )

    # E: one indefinite-length array wrapping every record (needs the break byte)
    variants["CBOR indef array"] = (
        SELF_DESCRIBE + enc(header) + indefinite_array([list(r) for r in recs])
    )

    # F: blocked -- 1000 records per definite-length array, seekable + chunk-compressible
    blocks = [
        [list(r) for r in recs[i : i + 1000]] for i in range(0, len(recs), 1000)
    ]
    variants["CBOR seq, 1000-rec blocks"] = (
        SELF_DESCRIBE + enc(header) + b"".join(enc(b) for b in blocks)
    )

    baseline = len(variants["JSON lines (keyed)"])
    print(f"{N} records @ {RATE_HZ} Hz ({MINUTES} min), fields={FIELDS}\n")
    print(f"{'encoding':<28} {'bytes':>10} {'B/rec':>7} {'vs JSON':>8} {'+zlib':>10}")
    print("-" * 68)
    for name, blob in variants.items():
        z = len(zlib.compress(blob, 6))
        print(
            f"{name:<28} {len(blob):>10} {len(blob) / N:>7.1f} "
            f"{len(blob) / baseline:>7.0%} {z:>10}"
        )


if __name__ == "__main__":
    main()
