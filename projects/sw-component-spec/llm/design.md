# Task: design view (`design.tex`)

This file has three free-text sections of the *Component Description* chapter (SWE.2 static and dynamic aspects, ISO 26262-6 clause 7). The tester needs them to derive integration and component test cases.

- **`StaticArchitecture`:** printed below the generated units table and structure diagram. Add what they don't show: layering, which unit owns which state, visibility, integrity levels of the units and freedom from interference if they differ.
- **`DynamicBehavior`:** modes and transitions of the component, call sequences between the units (e.g. one cycle of the main function), tasks and call rates, timing and ordering constraints.
- **`ErrorHandling`:** faults the component detects, which unit detects them, and the reaction (mode, output, diagnostic event, recovery).

Stay at component level: describe how the units work together, not how each unit works inside (that is in the unit's detailed design).

Each block is any LaTeX. Use paragraphs, `itemize`, `tabular` with `\toprule`/`\midrule`/`\bottomrule` inside `\begin{center}...\end{center}`, math and `\subsubsection{}` for longer sections. Write `\end{DynamicBehavior}` etc. on its own line.

## Figures

- Image file in the component's `figures/` folder: `\includegraphics[width=0.75\linewidth]{name}` inside a `figure` with `\caption{}` and `\label{fig:...}`.
- TikZ code in `figures/name.tex`: `\InputFigure{name}`, e.g. a sequence diagram. Write TikZ only if the engineer asks for it. Keep it simple, write `\_` in node text, and prefix your own style names (`mc unit/.style`), because short names like `step` or `out` already exist in TikZ.

## Write it from the engineer's input

1. Use unit and interface names exactly as in `component.tex`.
2. Don't invent modes, sequences or reactions. Ask for them.
3. Make every rule checkable, so that a test case can be derived from it. If a statement isn't, mention it in the open points.

## Example

```latex
\begin{ErrorHandling}
\begin{center}
\begin{tabular}{lll}
  \toprule
  \textbf{Fault} & \textbf{Detected by} & \textbf{Reaction} \\ \midrule
  NvM read fails          & \texttt{setpoint\_ctrl} & default setpoint 20, \texttt{DEM\_E\_NVM\_READ} \\
  Temperature implausible & \texttt{temp\_filter}   & SAFE mode within one cycle \\
  \bottomrule
\end{tabular}
\end{center}
\end{ErrorHandling}
```
