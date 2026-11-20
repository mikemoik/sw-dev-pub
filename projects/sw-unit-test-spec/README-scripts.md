# Scripts: new units and building

Run from the template's root folder. Python 3.6+ (standard library only) and `latexmk` are needed.

## Shipped units

- `units/empty/`: the skeleton for new units. It holds commented command templates and no content. `new_unit.py` copies it.
- `units/sample/`: a fully filled worked example. Use it to check that your setup builds (`python3 scripts/build.py sample`), and as a reference for how each content command and free-text block is used.

## New unit

```sh
python3 scripts/new_unit.py nvm_mgr                 # copies units/empty/ to units/nvm_mgr/
python3 scripts/new_unit.py nvm_mgr --from sample   # copies another unit instead
python3 scripts/new_unit.py --add-missing --all     # existing units: add the skeleton files they lack
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

## Clean

```sh
python3 scripts/clean.py              # everything
python3 scripts/clean.py sample       # one unit
python3 scripts/clean.py -n           # only list what would be removed
```

Removes the PDFs and LaTeX intermediates of `build.py` (`build/`) and of IDE or `latexmk` builds in the root folder (`<unit>.*`, `sw_unit_test_spec.*`). The committed preview `sw_unit_test_spec.pdf` is kept.

## Chat with an LLM

Guides in `llm/` tell a chat model how the template works, so it can help fill in a unit's content files ("add a test case for a setpoint of 101"). The model asks for missing facts and answers with LaTeX lines to paste.

**VS Code with Continue:** with the template folder open as workspace, Continue loads the matching context (common rules, the guide for that file, command reference, example) automatically when a content file such as `units/<unit>/testcases.tex` is in the chat. Use Chat mode only.

**Any other chat:** `scripts/llm_prompt.py` puts the same rules, the guide, the unit's file and the related files into one prompt to paste as the first chat message:

```sh
python3 scripts/llm_prompt.py nvm_mgr testcases -o build/prompt.md
python3 scripts/llm_prompt.py nvm_mgr unit --add ../src/nvm_mgr.h -o build/prompt.md   # with extra input
```

The prompt is about 2K–5K tokens plus `--add` files. Above 32000 it warns (`--max-tokens`). `--no-example` leaves out the worked example from `units/sample/`.

**Figures:** the rules and prompts list the specfig figure types. Ask for a figure in the chat; if the type's guide is missing, the model says which one to add. With Continue, create the figure file and add it to the chat (Continue then adds the type's guide); without, add `--figure`:

```sh
python3 scripts/new_figure.py nvm_mgr sequence cycle                         # units/nvm_mgr/figures/sequence_cycle.tex
python3 scripts/llm_prompt.py nvm_mgr design --figure sequence -o build/prompt.md
python3 scripts/llm_context.py nvm_mgr --figure gantt                        # whole-unit context + a type not used yet
```

`llm_context.py --figure` lasts until the next build; after that, a figure file of the type keeps its guide in.

**Whole unit in one file:** every build (`build.py`, `latexmk`, also each `-pvc` rebuild) rewrites `units/<unit>/llm-context.md` through `latexmkrc`. It holds the rules, all guides and command references, the figure guides of the specfig types the unit uses, an index of the declared IDs and all content and figure files of the unit. In Continue, reference only that file (`@llm-context.md`) for requests that touch several files or a figure; the per-file rules stay for small edits. The file is the state of the last build: after applying an answer, save (so `-pvc` rebuilds) and start a new chat or reference the file again. About 15K tokens for the sample.

```sh
python3 scripts/llm_context.py nvm_mgr            # write it without building
python3 scripts/llm_context.py nvm_mgr --check    # exit 1 if out of date
```

**Collect knowledge first:** `units/<unit>/knowledge.md` gathers facts about the unit from its sources, one file at a time: code (`.h`, `.c`, `.py`, ...), documents (`.md`, text from a PDF, images if the model takes them), requirement exports (`.csv`). Open the input file, add `@knowledge.md` to the chat and write "ingest" (optionally a hint, e.g. "only the NvM part"). The model answers with the whole updated file: replace `knowledge.md` with it and check `git diff`. Then the next input in a new chat. The prompts above and `llm-context.md` include `knowledge.md` (`llm-context.md` from the next build), so the spec chats take facts from it. Example: `units/sample/knowledge.md`.

**Maintainers:** `llm/_common.md` (role, chat protocol, LaTeX rules, shared helpers) and `llm/<file>.md` (one guide per content file) are the source. `llm/knowledge.md` is the guide for `knowledge.md`. `.continue/rules/` is generated from them plus `units/empty/` and `units/sample/`, and committed. After changing any of these:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```

More details are in [README.md](README.md).
