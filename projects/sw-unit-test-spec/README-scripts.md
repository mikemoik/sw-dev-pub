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

## Chat with an LLM about a content file

```sh
python3 scripts/llm_prompt.py nvm_mgr testcases -o build/prompt.md                 # prompt for testcases.tex
python3 scripts/llm_prompt.py nvm_mgr unit --add ../src/nvm_mgr.h -o build/prompt.md # with extra input
```

Paste the prompt as the first message of a new chat, then ask in plain language, e.g. "add a test case for a setpoint of 101". The model asks for missing facts and answers with LaTeX lines to paste into the file. Afterwards check them with `python3 scripts/build.py --strict nvm_mgr`.

The prompt contains the general rules (`llm/_common.md`), the guide for that file (`llm/<file>.md`, e.g. how to derive a test case), the command reference from `units/empty/`, the matching file of `units/sample/` as a worked example (`--no-example` leaves it out), the unit's file, the related files (e.g. requirements and interfaces for test cases), and any `--add` files. The script prints an estimate of the size. Prompts are about 2K–5K tokens plus any `--add` files; above 32000 (`--max-tokens`) it warns. Large-context models such as Gemma 4 31B take this easily, but check the context length your server is set to: e.g. Ollama uses a small default (`num_ctx`), and a model that runs out of context forgets the start of the chat, i.e. the rules. Don't paste confidential content into a chat service your organisation doesn't allow.

### In VS Code with Continue

`.continue/rules/` holds one rule per content file. When `units/<unit>/testcases.tex` is in the chat context (the open file, or added with `@`), Continue adds the common rules and the test case guide, with command reference and worked example, to the chat automatically. You chat right away, without a prompt to paste. The model reads the related files itself (e.g. `requirements.tex`, `unit.tex`) if its tools allow it, otherwise add them with `@`.

Open the template folder itself as the VS Code workspace: Continue looks for `.continue/rules/` at the top of the workspace.

The rules are generated from `llm/`, `units/empty/` and `units/sample/`. After changing one of these, run:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```

More details are in [README.md](README.md).
