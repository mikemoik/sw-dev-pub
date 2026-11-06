# Chat help with an LLM

An LLM in VS Code helps you fill in a unit's content files: "add a test case for a setpoint of 101", "derive boundary tests for SetpointCtrl_Set()", "which requirements have no test case?". Guides in `llm/` tell the model how the template works. The model asks for missing facts and answers with LaTeX lines to paste.

## Setup in VS Code (Continue)

Assumes Gemma 4 (e.g. `gemma4-31b-it`) is already running on a server Continue can reach.

1. Install the Continue extension: Extensions view → search *Continue* → install, or run

   ```sh
   code --install-extension Continue.continue
   ```

2. In Continue's config (`~/.continue/config.yaml`, gear icon in the Continue panel), check the model entry:

   ```yaml
   models:
     - name: Gemma 4 31B
       provider: ollama              # or openai for any OpenAI-compatible server
       model: gemma4-31b-it          # name as known to your server
       # apiBase: http://<host>:<port>/v1   # if not the provider's default
       roles: [chat, edit, apply]
       capabilities: [tool_use]      # lets the model read related files itself; only if your server supports tool calls for Gemma 4
       defaultCompletionOptions:
         contextLength: 32000        # at least 16000; the server must allow it too (Ollama: num_ctx)
   ```

3. Open **the template folder itself** as the workspace (*File → Open Folder*). Continue reads the rules from `.continue/rules/` at the top of the workspace. If the template is inside a larger workspace, copy `.continue/` to that workspace's top folder.

Nothing else to install. The rules come with the template.

## Use

1. Open a content file, e.g. `units/nvm_mgr/testcases.tex`. If it isn't in the chat context automatically, add it with `@` or select some lines and press Ctrl+L.
2. Ask in plain language in the Continue chat. Continue loads the common rules and the guide for that file (with command reference and an example) automatically.
3. Related files (for test cases: `requirements.tex`, `unit.tex`) are read by the model itself in agent mode with tools. Otherwise add them with `@`.
4. Paste the answer into the file and check it: `python3 scripts/build.py --strict nvm_mgr`. Red marks in the PDF show inconsistencies.

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
