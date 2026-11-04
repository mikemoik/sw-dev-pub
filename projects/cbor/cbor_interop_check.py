"""Cross-check CBOR logger streams against Python cbor2 (the reference decoder).

Answers: "do the MATLAB (cborenc/cbordec) and C++ (cbor.hpp) codecs produce and
consume CBOR that an independent implementation agrees with?"

    python cbor_interop_check.py read  <file.cbor>   # decode with cbor2, print header + blocks
    python cbor_interop_check.py write <file.cbor>   # write a reference stream with cbor2

`read` expects the logger layout from CBOR_CHEATSHEET.md: tag 55799 + header
map, then record blocks = arrays of RFC 8746 typed arrays (tags 64..87).  It
prints every item and fails (exit 1) if a block is not an array of typed
arrays or if the header lacks `fields`.  `write` emits the same layout using
only cbor2 primitives (CBORTag + bytes), plus one big-endian block and a tag
1040 matrix, so the other decoders get exercised on input they did not write.

Needs `pip install cbor2` (not a system package; use a venv).
"""
import struct
import sys

import cbor2

TAG_TO_FMT = {  # RFC 8746 tag -> struct format (endianness + code)
    64: 'B', 65: '>H', 66: '>I', 67: '>Q', 68: 'B', 69: '<H', 70: '<I', 71: '<Q',
    72: 'b', 73: '>h', 74: '>i', 75: '>q', 77: '<h', 78: '<i', 79: '<q',
    80: '>e', 81: '>f', 82: '>d', 84: '<e', 85: '<f', 86: '<d',
}


def unpack_typed(tag):
    fmt = TAG_TO_FMT[tag.tag]
    width = struct.calcsize(fmt)
    n = len(tag.value) // width
    return list(struct.unpack(fmt[0] + fmt[-1] * n if len(fmt) == 2 else fmt * n, tag.value))


def load_all(path):
    items = []
    with open(path, 'rb') as f:
        while True:
            try:
                items.append(cbor2.load(f))
            except (EOFError, cbor2.CBORDecodeEOF):
                break
    return items


def do_read(path):
    items = load_all(path)
    if not items:
        sys.exit('empty stream')
    hdr = items[0]
    print('header:', dict(hdr))
    if 'fields' not in hdr:
        sys.exit('header has no fields')
    ok = True
    for k, blk in enumerate(items[1:], 1):
        if isinstance(blk, cbor2.CBORTag) and blk.tag in (40, 1040):
            dims, data = blk.value
            vals = unpack_typed(data) if isinstance(data, cbor2.CBORTag) else data
            print(f'item {k}: multi-dim tag {blk.tag} dims={list(dims)} data={vals}')
            continue
        if not isinstance(blk, list) or not all(isinstance(c, cbor2.CBORTag) and c.tag in TAG_TO_FMT for c in blk):
            print(f'item {k}: NOT a block of typed arrays: {blk!r}')
            ok = False
            continue
        cols = {name: unpack_typed(c) for name, c in zip(hdr['fields'], blk)}
        print(f'item {k}: block', {n: (f'tag{c.tag}', v) for (n, v), c in zip(cols.items(), blk)})
    print('OK' if ok else 'FAILED')
    sys.exit(0 if ok else 1)


def do_write(path):
    hdr = {'v': 1, 'dev': 'ref', 't0': 1756944000, 'dt_ms': 10, 'fields': ['t', 'ax']}
    with open(path, 'wb') as f:
        f.write(cbor2.dumps(cbor2.CBORTag(55799, hdr)))
        for blk in range(2):
            t = [(blk * 4 + k) * 10 for k in range(4)]
            ax = [x * 0.1 for x in t]
            f.write(cbor2.dumps([cbor2.CBORTag(70, struct.pack('<4I', *t)),
                                 cbor2.CBORTag(85, struct.pack('<4f', *ax))]))
        # big-endian block (tags 66 / 81) -- readers must byte-swap
        f.write(cbor2.dumps([cbor2.CBORTag(66, struct.pack('>4I', 80, 90, 100, 110)),
                             cbor2.CBORTag(81, struct.pack('>4f', 8, 9, 10, 11))]))
        # 2x3 column-major float64 matrix, tag 1040
        f.write(cbor2.dumps(cbor2.CBORTag(1040, [[2, 3], cbor2.CBORTag(86, struct.pack('<6d', 1, 2, 3, 4, 5, 6))])))
        # float16 typed array (tag 84), indefinite-length array of plain items
        f.write(cbor2.dumps(cbor2.CBORTag(84, struct.pack('<3e', 1.0, 1.5, -2.0))))
    print('wrote', path)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('read', 'write'):
        sys.exit(__doc__)
    (do_read if sys.argv[1] == 'read' else do_write)(sys.argv[2])
