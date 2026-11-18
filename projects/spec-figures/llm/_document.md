# Figure documents

A figure document is a folder `figures/<document>/` of the spec-figures project: `document.tex` with the text, plus one file per figure in the same folder. The main file `spec_figures.tex` provides the document class, the packages and the commands below; `document.tex` holds only the body (no `\documentclass`, no `\usepackage`, no `\begin{document}`).

## Commands in `document.tex`

- **`\Title{title}{subtitle}`:** the heading block, once at the top. The subtitle may be empty `{}`.
- **`\InputFigure[max width]{name}`:** the figure file `name.tex` of this folder (or an image `name.pdf` / `.png` / `.jpg`), shrunk to the width (default the line width), never enlarged. Same command as in the document templates, so a figure file moves there unchanged.
- **`\ShowFigure[max width]{name}`:** the figure centred, then its source as a listing.
- **`\ShowSource{path}`:** any file as a listing, path from the project root (e.g. `figures/brake_mon/data.csv`).
- **`\ShowMermaid{type}`:** the Mermaid twin `mermaid/<type>.mmd` of a figure type, if there is one.
- **`\FigDir`:** the folder of this document (`figures/<document>/`).
- Everything else is ordinary LaTeX: `\section`, `itemize`, `tabular` (`booktabs` is loaded), `figure` with `\caption` and `\label`.

A figure with a caption:

```latex
\begin{figure}[htbp]
  \centering
  \InputFigure{sequence_ctrl_cycle}
  \caption{One control cycle of heater_ctrl}\label{fig:cycle}
\end{figure}
```

A RACI matrix is a table: put it in `\begin{table}` or `\begin{center}`, not in a `figure` with other drawings.

## Rules

- A new figure: write its file `figures/<document>/<type>_<name>.tex` (one environment, nothing else) and the line that includes it in `document.tex`. Give both, each in its own code block with the line saying where it goes.
- Text in `document.tex`: short and precise; refer to figures with `\ref{fig:...}`. Escape `\%` `\&` `\#` `\$`; `_` may be typed as is.
- Don't change the commands' definitions; they live in `spec_figures.tex`.
