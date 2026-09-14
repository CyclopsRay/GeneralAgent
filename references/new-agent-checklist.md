# Bootstrapping another agent

Work through these in order. The traps you hit during setup are the most valuable output: write
each one into the instruction files so no later session hits it again.

## 1. Budget and roles

- [ ] Decide which tokens are scarce (Claude, Codex, or neither). That decides who types code.
- [ ] Write the division of labor and the routing table into the global instruction file (§3).

## 2. Probe the environment and record the results

```bash
CODEX=$(ls -d ~/.vscode-server/extensions/openai.chatgpt-*/bin/*/codex | sort -V | tail -1); echo "$CODEX"
"$CODEX" --version && "$CODEX" debug models | head      # which model names this plan has
scripts/codex_run.sh --role code --effort low --cd "$(mktemp -d)" "Reply OK. Edit nothing."
quota -s; df -h "$HOME" /scratch 2>/dev/null            # where big outputs may go
module avail 2>&1 | head; conda env list                # software stack
which pdflatex pdffonts; fc-match Arial                 # LaTeX, fonts (Nimbus Sans = no Arial)
git config user.name; git config user.email
```

- [ ] The Codex smoke test prints a `session_id` and exits 0. If it fails with `bwrap … No space
      left on device`, the sandbox needs network access (the wrapper already sets it).
- [ ] Record the scheduler (SLURM partitions, accounts), scratch paths, and quotas in the global
      instructions.
- [ ] Note symlinked paths (`readlink -f`). Codex trust entries need the resolved path.

## 3. Instruction layers (keep each file short, because all of them load every session)

- [ ] `~/.claude/CLAUDE.md`: who the user is, the division of labor, routing, Codex invocation,
      the delegation workflow. Minimal starting point:
      ```markdown
      # Working with Codex
      Claude usage is scarce; Codex is not. Claude designs and reviews; Codex implements.
      Use the GeneralAgent skill for routing, invocation, and the delegation loop.
      Always pass Codex a model and effort explicitly. Never use danger-full-access.
      Scientific correctness is Claude's responsibility; Codex passing its own tests is not evidence.
      ```
- [ ] `~/.codex/AGENTS.md`: the same contract from the implementer's side. Stay inside the files
      the spec names; finish with the changed files and check results; never push; never weaken a
      test to make it pass.
- [ ] Project `CLAUDE.md` plus `AGENTS.md` (a symlink to it is fine) in each repo: what the repo is,
      live versus frozen files, sibling code repos, build and compile commands, domain traps, commit
      rules, and a pointer to the figure standard.

## 4. Skills

- [ ] Install from one repo by symlink, so the Claude and Codex copies never drift:
      ```bash
      ln -s /path/to/GeneralAgent ~/.claude/skills/GeneralAgent
      ln -s /path/to/GeneralAgent ~/.codex/skills/GeneralAgent
      ```
- [ ] Verify: in Claude Code, `/GeneralAgent` appears in the `/` menu; in Codex,
      `codex debug prompt-input "hi" | grep -c GeneralAgent` is non-zero.
- [ ] A skill installed in only one tool changes behavior in that tool alone. Check that
      `~/.claude/skills` and `~/.codex/skills` hold the same versions.

## 5. Memory

- [ ] Claude Code: auto memory is per project directory. Seed it with the user's role, expertise,
      and language preferences.
- [ ] Codex: `[features] memories = true` in `~/.codex/config.toml`.
- [ ] Save every correction of how the agent works, with the reason.

## 6. Permissions

- [ ] Claude Code: allowlist common read-only commands (`/fewer-permission-prompts` builds the list
      from transcripts) in `.claude/settings.json`. Leave `git push` and destructive commands
      prompting.
- [ ] Codex: `~/.codex/rules/*.rules` with `prefix_rule(pattern=[…], decision="allow")` for safe
      repeated commands; `[projects."<resolved path>"] trust_level = "trusted"` for working repos.

## 7. Repo hygiene

- [ ] Every project is a git repo, manuscripts included, and `.gitignore` covers build output.
- [ ] Figure projects have `figures/` dossiers, a `FIGURE_PROVENANCE.md`, and a caption sync script.
- [ ] Commit rules are written into the project instructions (named paths only, no push).

## 8. End-to-end dry run

Give the new agent one small real task and watch the whole loop: mode chosen → spec written →
Codex run in the background → diff reviewed → fix sent via `--resume` → commit of named files only
→ final message listing what was verified and what was not. Anything that went wrong goes into the
instructions before real work starts.
