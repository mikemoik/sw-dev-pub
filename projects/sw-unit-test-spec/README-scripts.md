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

## Chat with an LLM

Guides in `llm/` tell a chat model how the template works, so it can help fill in a unit's content files ("add a test case for a setpoint of 101"). The model asks for missing facts and answers with LaTeX lines to paste.

**VS Code with Continue:** with the template folder open as workspace, Continue loads the matching context (common rules, the guide for that file, command reference, example) automatically when a content file such as `units/<unit>/testcases.tex` is in the chat. Use Chat mode only.

**Any other chat:** `scripts/llm_prompt.py` puts the same rules, the guide, the unit's file and the related files into one prompt to paste as the first chat message:

```sh
python3 scripts/llm_prompt.py nvm_mgr testcases -o build/prompt.md
python3 scripts/llm_prompt.py nvm_mgr unit --add ../src/nvm_mgr.h -o build/prompt.md   # with extra input
```

The prompt is about 2K–5K tokens plus `--add` files. Above 32000 it warns (`--max-tokens`). `--no-example` leaves out the worked example from `units/sample/`.

**Maintainers:** `llm/_common.md` (role, chat protocol, LaTeX rules, shared helpers) and `llm/<file>.md` (one guide per content file) are the source. `.continue/rules/` is generated from them plus `units/empty/` and `units/sample/`, and committed. After changing any of these:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```

More details are in [README.md](README.md).
