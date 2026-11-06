# Chat help with an LLM

An LLM in VS Code helps you fill in a unit's content files: "add a test case for a setpoint of 101", "derive boundary tests for SetpointCtrl_Set()", "which requirements have no test case?". Guides in `llm/` tell the model how the template works. The model asks for missing facts and answers with LaTeX lines to paste.

## Setup in VS Code (Continue)

Continue and its Gemma 4 chat model (e.g. `gemma4-31b-it`) are already installed and configured on your system. Only two things to do:

1. In the Continue panel, choose the **Chat** mode. **Agent mode must not be used**: the model gets no tools and doesn't read or change files itself.
2. Open **the template folder itself** as the workspace (*File → Open Folder*). Continue reads the rules from `.continue/rules/` at the top of the workspace. If the template is inside a larger workspace, copy `.continue/` to that workspace's top folder.

The rules come with the template.

## Use

1. Open a content file, e.g. `units/nvm_mgr/testcases.tex`, and add it to the chat with `@` (or select some lines and press Ctrl+L). Continue then adds the common rules and the guide for that file (with command reference and an example) automatically.
2. Add the related files with `@` too. For test cases: `@requirements.tex @unit.tex`. The guide names them, and the model asks for them if they are missing.
3. Ask in plain language in the Continue chat.
4. Copy the answer into the file yourself and check it: `python3 scripts/build.py --strict nvm_mgr`. Red marks in the PDF show inconsistencies.

New units need nothing extra: the rules match every `units/<unit>/` folder, including those made with `new_unit.py`.

Don't paste confidential content into a model or server your organisation doesn't allow.

## Without Continue (any chat)

`scripts/llm_prompt.py` puts the same rules, the guide, the unit's file and the related files into one prompt to paste as the first chat message:

```sh
python3 scripts/llm_prompt.py nvm_mgr testcases -o build/prompt.md
python3 scripts/llm_prompt.py nvm_mgr unit --add ../src/nvm_mgr.h -o build/prompt.md   # with extra input
```

The prompt is about 2K–5K tokens plus `--add` files. Above 32000 it warns (`--max-tokens`). `--no-example` leaves out the worked example from `units/sample/`.

## Maintainers

`llm/_common.md` (role, chat protocol, LaTeX rules, shared helpers) and `llm/<file>.md` (one guide per content file) are the source. `.continue/rules/` is generated from them plus `units/empty/` and `units/sample/`, and committed. After changing any of these:

```sh
python3 scripts/continue_rules.py           # regenerate .continue/rules/
python3 scripts/continue_rules.py --check   # exit 1 if out of date (e.g. in CI)
```
