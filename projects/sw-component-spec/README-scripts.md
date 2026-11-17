# Scripts: new components and building

Run from the template's root folder. Python 3.6+ (standard library only) and `latexmk` are needed.

## Shipped components

- `components/empty/`: the skeleton for new components. It holds commented command templates and no content. `new_component.py` copies it.
- `components/sample/`: a fully filled worked example (component `heater_ctrl`). Use it to check that your setup builds (`python3 scripts/build.py sample`), and as a reference for how each content command and free-text block is used.

## New component

```sh
python3 scripts/new_component.py brake_mon                 # copies components/empty/ to components/brake_mon/
python3 scripts/new_component.py brake_mon --from sample   # copies another component instead
```

Component names: letters, digits, `_`, `-`, `.`. Then fill in the files in `components/brake_mon/`.

## Build

```sh
python3 scripts/build.py brake_mon          # -> build/brake_mon.pdf
python3 scripts/build.py brake_mon sample   # several components
python3 scripts/build.py --all              # all components except components/empty
```

| Option | Effect |
|---|---|
| `--force` | rebuild even if up to date |
| `--strict` | LaTeX warnings count as failure (e.g. CI) |
| `-v` | show the latexmk output |

PDFs go to `build/<component>.pdf` (gitignored, safe to delete). At the end you get a summary of each component's warnings and errors. If a component fails, its PDF is removed and the script exits non-zero.

## Clean

```sh
python3 scripts/clean.py              # everything
python3 scripts/clean.py sample       # one component
python3 scripts/clean.py -n           # only list what would be removed
```

Removes the PDFs and LaTeX intermediates of `build.py` (`build/`) and of IDE or `latexmk` builds in the root folder (`<component>.*`, `sw_component_spec.*`). The committed preview `sw_component_spec.pdf` is kept.

## Chat with an LLM

Guides in `llm/` tell a chat model how the template works, so it can help fill in a component's content files ("add a test case for a sensor fault"). The model asks for missing facts and answers with LaTeX lines to paste.

**VS Code with Continue:** with the template folder open as workspace, Continue loads the matching context (common rules, the guide for that file, command reference, example) automatically when a content file such as `components/<component>/testcases.tex` is in the chat. Use Chat mode only.

**Any other chat:** `scripts/llm_prompt.py` puts the same rules, the guide, the component's file and the related files into one prompt to paste as the first chat message:

```sh
python3 scripts/llm_prompt.py brake_mon testcases -o build/prompt.md
python3 scripts/llm_prompt.py brake_mon component --add ../src/brake_mon.h -o build/prompt.md   # with extra input
```

The prompt is about 3K–7K tokens plus `--add` files. Above 32000 it warns (`--max-tokens`). `--no-example` leaves out the worked example from `components/sample/`.

**Maintainers:** `llm/_common.md` (role, chat protocol, LaTeX rules, shared helpers) and `llm/<file>.md` (one guide per content file) are the source. `.continue/rules/` is generated from them plus `components/empty/` and `components/sample/`, and committed. After changing any of these:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```

More details are in [README.md](README.md).
