# Figure standard

A figure is finished only when it is **trackable** (anyone can find why it exists and rebuild it
from source) and **unified** (it looks like the rest of the paper). Strong science does not
excuse either one.

## Three records per figure

| Record | Holds | Authority for |
|---|---|---|
| Dossier `figures/<fig>.md` | mirrored caption, why the figure exists, the story, how to explain it, what it must **not** claim, decision log, open items | the reasoning |
| Provenance row (`FIGURE_PROVENANCE.md`) | asset path, generator script, source tables, rerun command, guardrails, status (current / superseded) | paths and commands |
| Source table | the exact plotted numbers, written by the generator next to the image | the numbers |

Write the dossier **before** drawing. If you cannot say what the figure must not claim, it is not
ready to draw. Update all three whenever a path, script, table, or status changes.

## Captions

The manuscript `.tex` is the single source of truth. The dossier mirrors the caption in a fenced
block, and a sync script reports drift and refreshes dossiers. It never writes to the `.tex`. Run
it before committing any caption change.

## Artwork

- No descriptive panel titles and no `suptitle`. Prose belongs in the caption; otherwise it is
  typeset twice, in two fonts, and the copies drift apart. Keep the bare panel letter:
  `ax.set_title("a", loc="left", fontweight="bold", fontsize=11)`.
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

- [ ] Dossier, provenance row, and source table exist and agree.
- [ ] The rerun command reproduces the asset from a clean shell.
- [ ] The caption is synced; the artwork contains no prose title; panel letters match the caption.
- [ ] Palette and fonts pass (`pdffonts`).
- [ ] The `.tex` compiles locally with no undefined references.
