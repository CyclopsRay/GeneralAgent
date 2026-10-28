# Figure standard

A figure is finished only when it is **trackable** (anyone can find why it exists and rebuild it
from source) and **unified** (it looks like the rest of the paper). Strong science does not
excuse either one.

## Records per figure

| Record | Holds | Authority for |
|---|---|---|
| Dossier `figures/<fig>.md`, next to the asset | see the required sections below | the reasoning, and how to rebuild |
| Source table | the exact plotted numbers, written by the generator next to the image | the numbers |
| Provenance index (`FIGURE_PROVENANCE.md`, optional) | one row per figure: asset, dossier, status | finding things |

Every figure gets its own dossier, a separate markdown file named after the asset. Required sections:

1. **Caption**: the caption, mirrored in a fenced block (see Captions).
2. **How the paper addresses it**: the `\label`, the section that introduces it, and for each panel the
   claim it supports and the sentence (or its gist) that cites it. A reader of the dossier alone
   should know what to say about the figure.
3. **Source**: the generator script(s), every input file or result directory with its job ID or
   report section, the source table, and the exact rerun command. Anyone must be able to trace each
   plotted number back to where it was produced.
4. **Must not claim**: what the figure does not show.
5. **Status and log**: current / superseded, and dated decisions (what changed and why).

Write the dossier **before** drawing. If you cannot say what the figure must not claim, it is not
ready to draw. Update the dossier and source table whenever a path, script, number, or status changes.

## Captions

The manuscript `.tex` is the single source of truth. The dossier mirrors the caption in a fenced
block, and a sync script reports drift and refreshes dossiers. It never writes to the `.tex`. Run
it before committing any caption change.

## Artwork

- **Words in the artwork: names only.** Each element (module, box, series, axis, group) carries a
  name, at most a short qualifier ("shared + per line"). What an element does, why it is there, and
  how to read the panel go in the caption; how it is computed goes in the methods. No sentences,
  explanations or takeaways inside the figure. Before saving, read every text string in the
  artwork and move anything longer than a label to the caption.
- No descriptive panel titles, subtitles or `suptitle`. Prose belongs in the caption; otherwise it is
  typeset twice, in two fonts, and the copies drift apart. Keep the bare panel letter:
  `ax.set_title("a", loc="left", fontweight="bold", fontsize=11)`.
- Prefer direct labels on the marks over a legend; if a legend is needed, put it where it does not
  sit on the data (outside the axes or in a margin row), never in the middle of a panel.
- Schematics: show what a module is (a network as neurons, an assay as cells and wells, a compound
  as a structure) with simple icons rather than describing it in words.
- `plt.rcParams["pdf.fonttype"] = plt.rcParams["ps.fonttype"] = 42` (editable text, not outlines).
- Define the palette once in a shared module. Each method gets a dark/light pair and keeps it in
  every figure; your own method always has the same colour. Example palette:
  ```python
  INK, MUTED, GRID = "#0b0b0b", "#898781", "#e1e0d9"
  OURS_C, OURS_L   = "#e34948", "#f6c3c2"
  BASE1_C, BASE1_L = "#4a3aa7", "#c5bfe6"
  BASE2_C, BASE2_L = "#2a78d6", "#bcd6f2"
  ```
- Save both `.pdf` and `.png` at `dpi=300`.
- Show the spread for repeated runs (points or a min–max bar).
- Drop the top and right spines; draw horizontal grid lines only.

## Font gate

Journals often require Arial. Arial is proprietary and usually missing on Linux clusters, where
`fc-match Arial` silently resolves to Nimbus Sans or Liberation Sans. A clean Matplotlib run
therefore proves nothing. The generator must:

1. load a licensed font file explicitly (a path or env var, e.g. `ARIAL_FONT=/path/arial.ttf`);
2. check the font's internal family name;
3. if the check fails, write a `_preview` basename so a draft can never pass as final.

Before submission, run `pdffonts fig.pdf`. The embedded family must not be `NimbusSans`,
`LiberationSans`, or `DejaVuSans`. Gene symbols may stay italic.

## Claims

- An illustrative panel says it was chosen and states the choice rule.
- The artwork asserts no more than the caption. If the caption declines to name an optimum, the
  artwork does not mark one.
- Stochastic results (clustering, subsampling): average ≥5 runs and argue at cohort level.
- Retired assets stay on disk, marked *superseded* in the provenance row.

## Before handing a figure over

- [ ] The dossier exists with all five sections; it and the source table agree with the asset.
- [ ] Every text string in the artwork is a name or short label; explanations are in the caption.
- [ ] The rerun command reproduces the asset from a clean shell.
- [ ] The caption is synced; the artwork contains no prose title; panel letters match the caption.
- [ ] Palette and fonts pass (`pdffonts`).
- [ ] The `.tex` compiles locally with no undefined references.
