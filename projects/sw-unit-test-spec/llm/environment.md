# Task: test environment (`environment.tex`)

This file lists what the tests run with. The test harness diagram is generated from `unit.tex` and needs nothing here.

- **`\Tool{item}{description}{version}`:** one per item: execution platform (host or target, processor), compiler and flags, test framework, mocking framework, coverage tool, CI. Give exact versions. Use `\code{...}` for flags (`gcc \code{-O0 -g --coverage}`).
- **`\ToolQualification{text}`:** tool confidence level (ISO 26262-8 clause 11), and qualification if needed.

## Things you can do

- Turn a pasted `CMakeLists.txt`, CI file or `--version` output into `\Tool` lines.
- Ask for anything that's missing: versions, target vs. host, coverage tool.
- Point out if tests run only on the host while the integrity level needs evidence on the target.

## Example

```latex
\Tool{Execution platform}{Host x86_64 (Linux)}{}
\Tool{Compiler / flags}{gcc \code{-O0 -g --coverage}}{14.2}
\Tool{Test framework}{GoogleTest}{1.15}
\ToolQualification{
  Tool confidence level TCL1 for all tools (ISO 26262-8 clause 11); no
  qualification needed.
}
```
