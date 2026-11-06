# Scripts: new units and building

Run from the template's root folder. Python 3.6+ (standard library only) and `latexmk` are needed.

## Shipped units

- `units/empty/`: the skeleton for new units. It holds commented command templates and no content. `new_unit.py` copies it.
- `units/sample/`: a fully filled worked example. Use it to check that your setup builds (`python3 scripts/build.py sample`), and as a reference for how each content command and free-text block is used.

## New unit

```sh
python3 scripts/new_unit.py nvm_mgr                 # copies units/empty/ to units/nvm_mgr/
python3 scripts/new_unit.py nvm_mgr --from sample   # copies another unit instead
```

Unit names: letters, digits, `_`, `-`, `.`. Then fill in the files in `units/nvm_mgr/`.

## Build

```sh
python3 scripts/build.py nvm_mgr          # -> build/nvm_mgr.pdf
python3 scripts/build.py nvm_mgr sample   # several units
python3 scripts/build.py --all            # all units except units/empty
```

| Option | Effect |
|---|---|
| `--force` | rebuild even if up to date |
| `--strict` | LaTeX warnings count as failure (e.g. CI) |
| `-v` | show the latexmk output |

PDFs go to `build/<unit>.pdf` (gitignored, safe to delete). At the end you get a summary of each unit's warnings and errors. If a unit fails, its PDF is removed and the script exits non-zero.

More details are in [README.md](README.md).
