# Delegation: Codex CLI and Claude subagents

## Routing

| Work | Tool | Model | Effort |
|---|---|---|---|
| Hardest reasoning, second opinion, audits | Codex `--role think` | `gpt-6-astra` | `xhigh` |
| Code: implementation, refactors, scripts, test-fix loops | Codex `--role code` | `gpt-5.6-sol` | `xhigh` |
| Literature, references, simple data fetching, report generation | Codex `--role search` | `gpt-5.6-terra` | `high` |
| Review of a git diff | `codex review --uncommitted` (or `--base <branch>`) | as above | |
| Any of the above when Codex is unavailable | `k2` (K2-Horizon) | think/code `-e high`; search `-e low` or `-e medium` | |
| Broad codebase search when only the conclusion matters | Claude `Explore` subagent | — | — |
| Several independent investigations at once | Claude `general-purpose` subagents | — | — |

These are the three tiers in `~/.claude/CLAUDE.md`, which is authoritative. Use only them. Run
`codex-models` to see what is offered; when new models ship, map them onto the same three tiers
(env `CODEX_CODE_MODEL`, `CODEX_THINK_MODEL`, `CODEX_SEARCH_MODEL`, matching `*_EFFORT`) and
confirm with the user before switching to an unlisted model.
**Always pass model and effort explicitly**: `codex exec` otherwise defaults the effort to `none`.
Delegation is optional; a task that is faster or safer done directly is done directly.

## Running Codex

The wrapper `scripts/codex_run.sh` finds the binary, sets model, effort and
`model_reasoning_summary="detailed"`, applies the sandbox, redirects stdin, keeps Codex's output
visible on stdout while logging it, and lists changed files. The sandbox is **read-only** unless
you pass `--write`.

```bash
R=scripts/codex_run.sh                                          # inside this skill's directory
$R --role code --write --cd /path/project - < spec.md           # implement
$R --role think --cd /path/project "Why does X diverge?"        # consult (read-only)
$R --role search --cd "$SCRATCH" "Find the original paper for Y; give DOIs"
$R --resume <session_id> --role code --write --cd /path/project - < fixes.md  # same session
$R --timeout 3600 …                                             # treat a hang as unavailable
$R --dry-run --role code "…"                                    # print the command only
```

Outputs go to `--out` (default: `$CODEX_RUNS_DIR`, else `/nfs-stor/$USER/ai-history/codex-runs/`,
else `$TMPDIR/codex_runs/`, in a unique `<time>-<role>-XXXXXX/` so parallel runs never collide):

- `codex.log`, the full log;
- `last.txt`, Codex's final message;
- `command.txt`;
- `changed_files.txt`, files modified during the run (by mtime);
- in git repos, also `git_status_before.txt` and `git_status_after.txt`, which separate deletions
  and pre-existing uncommitted edits from Codex's own changes.

The printed summary includes the `session_id`; report it to the user. `--resume` requires
`--role` (or `--model`) because a resumed session otherwise continues on whatever model the
defaults give. Read the wrapper's own exit code, never a pipeline's (`… | tail` reports `tail`).

Without the wrapper, use the standard invocation from the global instructions (stdout visible,
never hidden behind `-o file >/dev/null`):

```bash
codex exec -m <model> \
  -c model_reasoning_effort="<effort>" \
  -c model_reasoning_summary="detailed" \
  --skip-git-repo-check "<prompt>" </dev/null
codex --search exec …                                     # --search goes BEFORE exec
codex exec resume --skip-git-repo-check <session_id> -m <model> -c model_reasoning_effort='"<effort>"' \
  -c model_reasoning_summary='"detailed"' "<prompt>" </dev/null
```

Add `-s workspace-write` (or, for `resume`, `-c sandbox_mode='"workspace-write"'`) only when the
task must write files.

## Fallback when Codex is unavailable: `k2`

Unavailable means Codex could not run or could not answer: binary missing or exit 127, spend cap
(`You hit your spend cap`, exit 1; do not retry, fall back for the rest of the session and tell the
user once), expired auth, quota or rate-limit rejection, 5xx, network failure, or a run hanging
past a reasonable wall time. The wrapper exits **3** and prints the matching `k2` tier in these
cases. `codex --version` working proves nothing; only a real round trip does. A weak answer is not
unavailability: re-prompt or fix it directly. Never run both for the same task unless asked.

```bash
k2 --health                                              # exit 0 = usable
k2 -e high "<prompt>"                                    # think / code tier
k2 -f train.py -f model.py -e high "why does loss go NaN at step 200?"
cat err.log | k2 -e low -s "Be terse."                   # search / report tier
```

- `k2` has no sandbox and no repo access: it sees only the prompt and `-f` files, so apply its
  output yourself.
- Reasoning counts against `--max-tokens` (default 16000). Exit 2 means `finish_reason=length`:
  re-run with a larger budget; never patch a truncated answer.
- Reasoning goes to stderr, the answer to stdout; keep stdout visible. Report the session id.
- Credentials live in `~/.config/ifm/credentials`; never put the key on a command line, in a file,
  a commit or a prompt. Do not switch models or providers without asking.

## Traps

| Symptom | Cause | Fix |
|---|---|---|
| `bwrap: Creating new namespace failed: No space left on device` | cluster disables network namespaces (seen on ACCRE: `max_net_namespaces=0`) | wrapper `--write --network` (`-c sandbox_workspace_write.network_access=true`). Never use `danger-full-access` to get around it |
| `exec` hangs with no output | it is reading stdin | `</dev/null`, or pass the prompt as `-` with `< spec.md` |
| refuses to run outside a git repo | trusted-directory check | `--skip-git-repo-check`, and snapshot or commit first so the change can be diffed |
| wrong model or effort | `config.toml` defaults | pass `-m` and `model_reasoning_effort` every time |
| `exec resume` rejects `-s` / `-C` | resume has neither flag | sandbox via `-c sandbox_mode="workspace-write"`; `cd` into the directory first |
| web search never happens | `--search` placed after `exec` | `codex --search exec …` |
| cannot write a file | the file is outside the workspace | make `--cd` cover every edited file, or add `--add-dir <dir>` |
| Codex's own test of a Codex call fails | a sandbox cannot start inside a sandbox | Codex tests with `--dry-run` and fake binaries; the orchestrator runs the real smoke test |
| trust entry in `config.toml` has no effect | symlinked path (`/data/...` → `/panfs/...`) | write trust entries with the resolved path (`readlink -f`) |

## Spec template

```markdown
# Task: <one line>
Working dir: <absolute path>. Edit only: <files>. Do not touch: <files>.

## Goal
What it is for and who uses the output.

## Interface
Inputs, outputs, CLI, file formats, column names.

## Constraints
Allowed dependencies, style of surrounding code, runtime and memory budget, seeds.

## Domain traps
Coordinate base (0/1), units, reference build, filters that must not change, known bad samples…

## Acceptance checks
Commands to run and the expected result of each.

Finish with: changed files; each check with its actual result; anything you could not do.
```

## Review checklist

- Did the changes stay inside the files the spec named? (`changed_files.txt`)
- Rerun the checks yourself, and on a small slice of real data, not only toy input.
- Look for silent weakening: loosened assertions, a broad `except`, skipped failing cases,
  hard-coded expected values, thresholds that changed without being asked for.
- Check the scientific substance yourself: denominators, units, coordinate bases, filtering order,
  leakage between tuning and evaluation data, multiple testing.
- Relay nothing from Codex's final message ("all tests pass") that you have not seen.

## Claude subagents (Claude Code `Agent` tool)

- A subagent starts with none of your context. Brief it like a new colleague: the goal, what you
  already know, what is ruled out, and the shape and length of the answer you want.
- Built-in types: `Explore` (read-only fan-out search; returns conclusions, not file dumps),
  `Plan` (implementation design), `general-purpose` (multi-step work). Define custom types in
  `.claude/agents/<name>.md`.
- Spawn one for context isolation or genuine parallelism. Don't spawn one for work you already have
  the context for, or for steps that depend on each other. Each spawn spends orchestrator tokens.
- Subagents run in the background, and a notification arrives when one finishes. Never predict or
  invent a pending result.
- The user never sees a subagent's report. Relay what matters.
- To follow up, continue the same subagent with `SendMessage` rather than spawning a fresh one.
- Parallel editors on one git repo: use `isolation: "worktree"`.
- A skill can run itself in a subagent: `context: fork` plus `agent: <type>` in its frontmatter.
- Codex has its own `multi_agent` feature inside a single Codex session. The orchestrator does not
  manage it.
