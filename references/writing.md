# Writing: reports versus papers

## Pick the mode by audience and purpose

| Report mode | Paper mode |
|---|---|
| Analysis and benchmark reports, progress updates, figure dossiers, provenance records, READMEs, review verdicts, answers to "how did it turn out" | Manuscript and SI text, title, abstract, introduction, results, discussion, conclusion, captions in the manuscript, rebuttals, cover letters |
| Readers need the true picture to make decisions | Readers need to understand why the work matters |

- Drafting paper text *from* a report is still paper mode.
- The message to the user after editing paper text is report mode.
- If the mode is unclear, ask.

## Report mode: faithful

- Lead with the answer, then the evidence.
- Keep positive and negative results side by side. A loss is a finding.
- State what failed, what was skipped, what was not checked, and the known confounds.
- For every number, give the source file or table, n, and spread.
- Separate verified from inferred. Write "not tested" rather than guess.
- No spin in either direction ("impressive", "unfortunately").
- Never drop an inconvenient result. The paper's story is chosen *from* the report, so the report
  must contain everything.

## Paper mode: the press-conference principle

> Adapted and condensed from
> [Adkid-Zephyr/anti-defensive-writing-Skill](https://github.com/Adkid-Zephyr/anti-defensive-writing-Skill)
> (MIT). See `NOTICE.md`.

A paper is a press conference, not a project summary, lab log, or self-audit. Find the work's
most publishable strength and build the most persuasive narrative around it.

**Narrative**
1. Organize around real strengths: a new capability, problem, mechanism, or perspective; broader
   applicability; lower cost; a meaningful trade-off. Material that forms no advantage stays out of
   the main line.
2. No chronology ("we first tried A, then B"). Keep the final logic: the problem matters →
   existing methods fall short → what this paper provides → the evidence.
3. Don't headline a metric you cannot win. Choose the task, scenario, or comparison frame that
   reflects the work's value, and justify that choice on scientific grounds in the text.
4. State the advantage explicitly: when the method is strongest, why, and what problem that solves.
   Reviewers should not have to dig it out of a table.
5. Claim only what the evidence firmly supports. Tight claim–evidence fit persuades more than the
   number of comparisons.
6. When the results do not support the original story, rebuild the story rather than defend it.

**Language**
- Cut self-weakening phrases: "unfortunately", "merely", "only achieves", "still lags far behind",
  "limited improvement", "it must be acknowledged".
- For an unfavorable result, ask in order: Must it be discussed? Is it explained by different goals,
  constraints, or scenarios? Is it a reasonable trade-off? Can the claim be narrowed? Should the
  story stop depending on it?
- Don't let a local observation read as a verdict on the whole method.
- When a limitation must be stated, state it once, plainly, and scoped:
  "Cross-domain generalization was not evaluated."

**Experiments.** Each experiment has one job: show that the method works, show that the advantage
comes from the key mechanism, show value in the target setting, or rule out the most plausible
alternative explanation. An experiment with no job is cut, shrunk, moved to the SI, or redesigned.

**Structure.** The opening sentences of the abstract and introduction establish four things: the
problem, the gap, the approach, and the strongest result. Don't raise limitations before the
contribution is established. The conclusion reinforces what was solved, what was shown, and why it
matters, with no new self-negation.

**When material is unfavorable, act in this order:** delete what is irrelevant to the core claim →
narrow the claim → pick a better-suited evaluation dimension → explain the result as a difference in
goals or a trade-off → reorganize so the advantage is the visual and narrative center → redefine
the story → only if unavoidable and it affects the core conclusion, state it plainly.

**Pre-submission check.** Does a sentence quietly widen what the paper must answer for, or raise a
question nobody asked? Does it describe a local effect as a general flaw, or judge more broadly than
the evidence allows? Is any passage a process diary? Is a losing metric the main battlefield? Do the
problem and the contribution both appear in the first five sentences of the abstract? Does the
conclusion slip in a self-negation?

### Floors that framing never overrides

1. Numbers, statistics, and facts are identical to their source. Nothing is invented, and no claim
   exceeds the evidence. An illustrative result is never presented as a cohort result.
2. After editing paper text, tell the user in report mode exactly what was cut, weakened, or moved
   to the SI.
3. Statements the journal requires (data and code availability, ethics, competing interests) are
   not defensive writing. Keep them.

## Manuscript mechanics

- Compile locally before pushing to Overleaf (`pdflatex` twice), and fix undefined references and
  missing assets.
- When a repo keeps an advisor-reviewed original next to a working copy, edit only the working
  copy unless told otherwise.
- Sync captions to the figure dossiers after caption edits (see `figures.md`).
