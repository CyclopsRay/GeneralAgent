# Delegation: Codex CLI and Claude subagents

## Routing

| Work | Tool | Model | Effort |
|---|---|---|---|
| Hardest reasoning, second opinion, audits | Codex `--role think` | `gpt-6-astra` | `xhigh` |
| Code: implementation, refactors, scripts, test-fix loops | Codex `--role code` | `gpt-5.6-sol` | `high` |
| Literature and references | Codex `--role search` | `gpt-5.6-terra` | `max` |
| Review of a git diff | `codex review --uncommitted` (or `--base <branch>`) | as above | |
| Broad codebase search when only the conclusion matters | Claude `Explore` subagent | — | — |
| Several independent investigations at once | Claude `general-purpose` subagents | — | — |

Model names depend on the plan. List yours with `codex debug models`, then remap through
`CODEX_CODE_MODEL`, `CODEX_THINK_MODEL`, `CODEX_SEARCH_MODEL` (and matching `*_EFFORT`).
Effort levels: low, medium, high, xhigh, max, ultra. **Always pass model and effort explicitly**,
because otherwise `~/.codex/config.toml` defaults apply silently.

## Running Codex

The wrapper `scripts/codex_run.sh` finds the binary, applies the sandbox flags, redirects stdin,
logs, and lists changed files:

```bash
R=scripts/codex_run.sh                                   # inside this skill's directory
$R --role code  --cd /path/project - < spec.md           # implement
$R --role think --cd /path/project "Why does X diverge?" # consult
$R --role search --cd /tmp/lit "Find the original paper for Y; give DOIs"
$R --resume <session_id> --role code --cd /path/project - < fixes.md  # follow-up, same session
$R --dry-run --role code "…"                             # print the command only
```

Outputs go to `--out` (default: a unique `$TMPDIR/codex_runs/<time>-<role>-XXXXXX/`, so parallel
runs never collide):

- `codex.log`, the full log;
- `last.txt`, Codex's final message;
- `command.txt`;
- `changed_files.txt`, files modified during the run (by mtime);
- in git repos, also `git_status_before.txt` and `git_status_after.txt`, which separate deletions
  and pre-existing uncommitted edits from Codex's own changes.

The printed summary includes the `session_id`. `--resume` requires `--role` (or `--model`) because
a resumed session otherwise continues on whatever model the defaults give. Run anything longer than
a couple of minutes in the background.

Without the wrapper, use these raw shapes (codex-cli 0.153):

```bash
CODEX=$(ls -d ~/.vscode-server/extensions/openai.chatgpt-*-linux-x64 | sort -V | tail -1)/bin/linux-x86_64/codex
$CODEX exec --skip-git-repo-check -C <dir> -m gpt-5.6-sol -c model_reasoning_effort='"high"' \
  -s workspace-write -c sandbox_workspace_write.network_access=true \
  -o <out>/last.txt "<prompt>" </dev/null > <out>/codex.log 2>&1
$CODEX --search exec …                                    # --search goes BEFORE exec
$CODEX exec resume --skip-git-repo-check <session_id> -m <model> -c model_reasoning_effort='"<effort>"' \
  -c sandbox_mode='"workspace-write"' -c sandbox_workspace_write.network_access=true \
  -o <out>/last.txt "<prompt>" </dev/null >> <out>/codex.log 2>&1
```

## Traps

| Symptom | Cause | Fix |
|---|---|---|
| `bwrap: Creating new namespace failed: No space left on device` | cluster disables network namespaces (ACCRE: `max_net_namespaces=0`) | `-c sandbox_workspace_write.network_access=true`. Never use `danger-full-access` to get around it |
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
  Hand bulk implementation to Codex instead.
- Subagents run in the background, and a notification arrives when one finishes. Never predict or
  invent a pending result.
- The user never sees a subagent's report. Relay what matters.
- To follow up, continue the same subagent with `SendMessage` rather than spawning a fresh one.
- Parallel editors on one git repo: use `isolation: "worktree"`.
- A skill can run itself in a subagent: `context: fork` plus `agent: <type>` in its frontmatter.
- Codex has its own `multi_agent` feature inside a single Codex session. The orchestrator does not
  manage it.
