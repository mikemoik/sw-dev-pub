# Task: tools (`environment.tex`)

Chapter 8: the tools of the project and their classification.

- **`\Tool{name}{purpose}{version}{classification}`:** one per tool used to build, test, analyse or release the software. The name is how rules, CI stages and how-tos in `development.tex` refer to it. Classification after ISO 26262-8 clause 11 (`TI1, TD1: TCL1`, `TI2, TD2: TCL2, validated by ...`); required when `\IntegrityLevel` is an ASIL, otherwise optional.
- **`\ToolQualification{text}`:** how and where tools are classified and qualified, and what happens when a tool version changes.

## Example

```latex
\Tool{cppcheck}{MISRA C:2012 static analysis}{2.16}{TI2, TD2: TCL2, validated by sample review}
```
