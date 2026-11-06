# Task: design view (`design.tex`)

This file has three free-text sections of the *Unit Under Test* chapter. The tester needs them to derive test cases (ISO 26262-6 9.4.3: analysis of the detailed design).

- **`IntendedBehavior`:** the observable behaviour: states and transitions, modes, what happens on errors, invariants (e.g. "$0 \le sp \le 100$ holds at all times"). A state table or list is often enough.
- **`InternalArchitecture`:** the inner parts of the unit (functions, modules, data) and how they work together. Mention what is static or persistent.
- **`AlgorithmDescription`:** calculations and decision logic, with formulas, value ranges, units, rounding and saturation, and timing (call rate).

Each block is any LaTeX. Use paragraphs, `itemize`, `tabular` with `\toprule`/`\midrule`/`\bottomrule` inside `\begin{center}...\end{center}`, math (`$...$`, `\[ ... \]`, `align`) and `\subsubsection{}` for longer sections. Write `\end{IntendedBehavior}` etc. on its own line.

## Figures

- Image file in the unit's `figures/` folder: `\includegraphics[width=0.75\linewidth]{name}` inside a `figure` with `\caption{}` and `\label{fig:...}`.
- TikZ code in `figures/name.tex`: `\InputFigure{name}`. Write TikZ only if the engineer asks for it. Keep it simple and prefix your own style names (`sc st/.style`), because short names like `step` or `out` already exist in TikZ.

## Write it from the engineer's input

The engineer may paste a design document excerpt, a state machine description or code. Turn it into the three blocks:

1. Use the names exactly as they appear in `unit.tex`.
2. Don't invent states, transitions or formulas. Ask for them.
3. Make every rule checkable, so that a test case can be derived from it. If a statement isn't, mention it in the open points.

## Example

```latex
\begin{IntendedBehavior}
The unit has two operating states. Transitions happen only in
\texttt{SetpointCtrl_Init()}; set requests never change the state.

\begin{center}
\begin{tabular}{lll}
  \toprule
  \textbf{State} & \textbf{Setpoint} & \textbf{Diagnosis} \\ \midrule
  IDLE     & last stored value (NvM)  & -- \\
  DEGRADED & default $sp_0 = 20$      & \texttt{DEM_E_NVM_READ} reported once \\
  \bottomrule
\end{tabular}
\end{center}
In both states $0 \le sp \le 100$ holds at all times.
\end{IntendedBehavior}
```
