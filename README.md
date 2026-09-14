# GeneralAgent

An agent skill (Claude Code and Codex) that captures how we run research projects with several
agents:

- **who does what:** the main session designs and reviews, Codex implements, and Claude subagents
  scout;
- **how to call Codex** on an HPC cluster without hitting the sandbox traps, using a wrapper script;
- **output modes:** code, figures (trackable and unified), reports (faithful, negatives kept), and
  paper text (no defensive wording, numbers unchanged);
- **science guardrails**, commit hygiene, and a checklist for bootstrapping a new agent.

## Layout

```
GeneralAgent/
├── SKILL.md                         core rules (loaded when the skill triggers)
├── references/
│   ├── delegation.md                Codex routing, traps, spec template, review, Claude subagents
│   ├── figures.md                   figure standard, font gate
│   ├── writing.md                   report mode vs paper mode
│   └── new-agent-checklist.md       setting up another agent
├── scripts/codex_run.sh             Codex wrapper (roles, sandbox flags, logs, changed files)
└── NOTICE.md                        third-party attribution
```

## Install

Symlink the repo so that Claude Code and Codex share one copy:

```bash
git clone <this repo> ~/GeneralAgent        # or copy the directory
mkdir -p ~/.claude/skills ~/.codex/skills
ln -s ~/GeneralAgent ~/.claude/skills/GeneralAgent
ln -s ~/GeneralAgent ~/.codex/skills/GeneralAgent
```

Check that both tools see it:

- Claude Code: `/GeneralAgent` appears in the `/` menu.
- Codex: `codex debug prompt-input "hi" | grep -c GeneralAgent` prints a non-zero count.

## Adapt before use

| What | Where |
|---|---|
| Codex model names for your plan (`codex debug models`) | env `CODEX_CODE_MODEL`, `CODEX_THINK_MODEL`, `CODEX_SEARCH_MODEL` (and `*_EFFORT`), or the table in `references/delegation.md` |
| Codex binary location, if not on PATH or in the VS Code extension | env `CODEX_BIN` |
| Palette and journal font | `references/figures.md` |
| Which tokens are scarce (who writes code) | `SKILL.md` §1 |

Then work through `references/new-agent-checklist.md`.

## Credits

The paper-mode rules condense
[anti-defensive-writing-Skill](https://github.com/Adkid-Zephyr/anti-defensive-writing-Skill)
(MIT); see `NOTICE.md`.
