# Figure: Package diagram

Packages, modules or directories and the dependencies between them: the layering of a component's code. Typical in component specifications (static architecture) and developer manuals (repository layout).

## TikZ: `\begin{sfPackage}[options]` … `\end{sfPackage}`

- **`\Package[c,r]{ID}{name}`:** a package (box with tab).
- **`\Element{name}`:** an element contained in the package just declared (module, unit, file); listed under the name.
- **`\Import[options]{from}{to}`:** dashed arrow «import».
- **`\Dependency[options]{from}{to}{label}`:** dashed arrow with a label, e.g. `uses`.
- **Options:** `xstep` (default 4.6cm), `ystep` (default 2.4cm).
- **Layout:** grid `[column,row]`; without a position a package goes right of the previous one. Layers: put higher layers left or above. A dependency that skips a package: `[left]` to bend it around.
- **Red marks:** unknown or duplicate ID, `\Element` before any package, bad position.

## Mermaid: `flowchart LR`

- Packages as `subgraph id [name]` … `end` with elements as boxes inside.
- `a -. "«import»" .-> b`, `a -. uses .-> b`.

## From a table

- Module list with columns *module*, *package*, *depends on* → one `\Package` per distinct package, `\Element` lines, and one `\Import` per package-level dependency (collapse module dependencies to their packages).
