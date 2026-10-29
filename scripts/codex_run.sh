#!/usr/bin/env bash
# Safe wrapper for delegating work to Codex. Follows the global rules in
# ~/.claude/CLAUDE.md: explicit model and effort, detailed reasoning summary,
# read-only sandbox unless --write, stdout kept visible (tee'd to the log),
# and a distinct exit code when Codex is unavailable so the caller can fall
# back to `k2` at the matching tier.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex_run.sh [options] (PROMPT | -)
  --role code|think|search   default: code
  --model M                  override the role's model
  --effort E                 low|medium|high|xhigh|max|ultra
  --write                    workspace-write sandbox (default: read-only)
  --network                  allow network inside the write sandbox; needed on
                             clusters without network namespaces (bwrap reports
                             "No space left on device")
  --timeout SECS             kill Codex after SECS of wall time (exit 124)
  --cd DIR                   working directory (default: $PWD; must exist)
  --out DIR                  output directory (default: $CODEX_RUNS_DIR, else
                             /nfs-stor/$USER/ai-history/codex-runs, else $TMPDIR)
  --resume SESSION_ID        continue an existing session
  --dry-run                  print the fully quoted command and exit
  -h, --help                 show this help

PROMPT of "-" reads the prompt from stdin.
Exit 3 means Codex is unavailable (missing binary, spend cap, auth, quota,
rate limit, 5xx, network): fall back to `k2` at the matching tier.
EOF
}

die_usage() {
  printf 'codex_run.sh: %s\nTry codex_run.sh --help for usage.\n' "$1" >&2
  exit 2
}

unavailable() {
  printf 'codex_unavailable: %s\n' "$1"
  printf 'fallback: k2 %s   (check first: k2 --health)\n' "$k2_tier"
  exit 3
}

quote_command() {
  local arg first=1
  for arg in "$@"; do
    (( first )) || printf ' '
    printf '%q' "$arg"
    first=0
  done
  printf '\n'
}

discover_codex() {
  local found base candidate
  local -a candidates=() tried=()
  if [[ -n "${CODEX_BIN:-}" ]]; then
    if [[ -x "$CODEX_BIN" ]]; then
      [[ $CODEX_BIN == /* ]] && printf '%s\n' "$CODEX_BIN" || printf '%s/%s\n' "$PWD" "$CODEX_BIN"
      return
    fi
    tried+=("CODEX_BIN=$CODEX_BIN (not executable)")
  else
    tried+=("CODEX_BIN (unset)")
  fi
  found=$(command -v codex 2>/dev/null || true)
  if [[ -n "$found" && -x "$found" ]]; then
    printf '%s\n' "$found"
    return
  fi
  tried+=("command -v codex")
  shopt -s nullglob
  for base in "$HOME/.vscode-server/extensions" "$HOME/.vscode/extensions"; do
    candidates=()
    for candidate in "$base"/openai.chatgpt-*/bin/*/codex; do
      [[ -x "$candidate" ]] && candidates+=("$candidate")
    done
    if (( ${#candidates[@]} )); then
      printf '%s\n' "${candidates[@]}" | sort -V | tail -n 1
      return
    fi
    tried+=("$base/openai.chatgpt-*/bin/*/codex")
  done
  printf 'codex_run.sh: no executable Codex CLI found; tried:\n' >&2
  printf '  - %s\n' "${tried[@]}" >&2
  return 1
}

role=code model_override= effort_override= out_dir= resume_id= prompt= timeout_s=
work_dir=$PWD
dry_run=0 have_prompt=0 role_set=0 model_set=0 resume_set=0 write=0 network=0
for raw_arg in "$@"; do
  case $raw_arg in
    --dangerously-bypass-approvals-and-sandbox|danger-full-access)
      die_usage "forbidden argument: $raw_arg" ;;
  esac
done
while (( $# )); do
  case $1 in
    --role|--model|--effort|--cd|--out|--resume|--timeout)
      option=$1
      (( $# >= 2 )) || die_usage "$option requires a value"
      case $option in
        --role) role=$2; role_set=1 ;; --model) model_override=$2; model_set=1 ;;
        --effort) effort_override=$2 ;; --cd) work_dir=$2 ;;
        --out) out_dir=$2 ;; --resume) resume_id=$2; resume_set=1 ;;
        --timeout) timeout_s=$2 ;;
      esac
      shift 2 ;;
    --write) write=1; shift ;;
    --network) network=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -)
      (( ! have_prompt )) || die_usage 'expected exactly one prompt'
      prompt=-; have_prompt=1; shift ;;
    -*) die_usage "unknown option: $1" ;;
    *)
      (( ! have_prompt )) || die_usage 'expected exactly one prompt'
      prompt=$1; have_prompt=1; shift ;;
  esac
done

(( have_prompt )) || die_usage 'missing prompt'
[[ -d "$work_dir" ]] || die_usage "working directory does not exist: $work_dir"
(( ! model_set )) || [[ -n "$model_override" ]] || die_usage 'model must not be empty'
(( ! resume_set )) || [[ -n "$resume_id" ]] || die_usage 'resume session ID must not be empty'
if [[ -n "$resume_id" ]] && (( ! role_set && ! model_set )); then
  die_usage 'resume requires --role or --model matching the original session'
fi
(( ! network || write )) || die_usage '--network only applies with --write'
[[ -z "$timeout_s" || "$timeout_s" =~ ^[1-9][0-9]*$ ]] || die_usage "bad timeout: $timeout_s"
work_dir=$(cd "$work_dir" && pwd -P)

# Tiers from ~/.claude/CLAUDE.md (authoritative; run `codex-models` to check).
search_flag=0
case $role in
  code)
    model=${CODEX_CODE_MODEL:-gpt-5.6-sol}; effort=${CODEX_CODE_EFFORT:-xhigh}
    k2_tier='-e high' ;;
  think)
    model=${CODEX_THINK_MODEL:-gpt-6-astra}; effort=${CODEX_THINK_EFFORT:-xhigh}
    k2_tier='-e high' ;;
  search)
    model=${CODEX_SEARCH_MODEL:-gpt-5.6-terra}; effort=${CODEX_SEARCH_EFFORT:-high}
    k2_tier='-e low (or -e medium)'; search_flag=1 ;;
  *) die_usage "bad role: $role" ;;
esac
[[ -n "$model_override" ]] && model=$model_override
[[ -n "$effort_override" ]] && effort=$effort_override
[[ -n "$model" ]] || die_usage 'model must not be empty'
case $effort in low|medium|high|xhigh|max|ultra) ;; *) die_usage "bad effort: $effort" ;; esac

if [[ -z "$out_dir" ]]; then
  out_parent=${CODEX_RUNS_DIR:-}
  if [[ -z "$out_parent" ]]; then
    if [[ -d /nfs-stor/$USER/ai-history ]]; then
      out_parent=/nfs-stor/$USER/ai-history/codex-runs
    else
      out_parent=${TMPDIR:-/tmp}/codex_runs
    fi
  fi
  out_template=$out_parent/$(date +%Y%m%d-%H%M%S)-$role-XXXXXX
  if (( dry_run )); then
    out_dir=$out_template
  else
    mkdir -p "$out_parent"
    out_dir=$(mktemp -d "$out_template")
  fi
elif [[ $out_dir != /* ]]; then
  out_dir=$PWD/$out_dir
fi

codex_bin=$(discover_codex) || unavailable 'no Codex binary'

if (( write )); then sandbox=workspace-write; else sandbox=read-only; fi
declare -a sandbox_cfg=(-c "sandbox_mode=\"$sandbox\"")
(( network )) && sandbox_cfg+=(-c sandbox_workspace_write.network_access=true)
declare -a common=(-m "$model"
  -c "model_reasoning_effort=\"$effort\""
  -c 'model_reasoning_summary="detailed"'
  "${sandbox_cfg[@]}"
  -o "$out_dir/last.txt" "$prompt")

declare -a command=()
[[ -n "$timeout_s" ]] && command+=(timeout "$timeout_s")
command+=("$codex_bin")
(( search_flag )) && command+=(--search)
if [[ -n "$resume_id" ]]; then
  command+=(exec resume --skip-git-repo-check "$resume_id" "${common[@]}")
else
  command+=(exec --skip-git-repo-check -C "$work_dir" "${common[@]}")
fi

if (( dry_run )); then
  quote_command "${command[@]}"
  exit 0
fi

mkdir -p "$out_dir"
quote_command "${command[@]}" >"$out_dir/command.txt"
[[ -n "$resume_id" ]] || : >"$out_dir/codex.log"
in_git=0
if git -C "$work_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
  git -C "$work_dir" status --porcelain >"$out_dir/git_status_before.txt"
fi
touch "$out_dir/.start"
run_command() {
  [[ -z "$resume_id" ]] || cd "$work_dir" || return
  "${command[@]}"
}
# Output stays visible and is also logged. The exit status is Codex's, not tee's.
set +e
if [[ $prompt == - ]]; then
  (run_command) 2>&1 | tee -a "$out_dir/codex.log"
else
  (run_command) </dev/null 2>&1 | tee -a "$out_dir/codex.log"
fi
codex_status=${PIPESTATUS[0]}
set -e

if (( in_git )); then
  git -C "$work_dir" status --porcelain >"$out_dir/git_status_after.txt"
fi
find "$work_dir" -type f -newer "$out_dir/.start" -not -path '*/.git/*' -print |
  sort | sed -n '1,500p' >"$out_dir/changed_files.txt"
session_id=$(sed -nE \
  's/^session id: ([[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}).*/\1/p' \
  "$out_dir/codex.log" | head -n 1)
session_id=${session_id:-unknown}
changed_count=$(wc -l <"$out_dir/changed_files.txt")
changed_count=${changed_count//[[:space:]]/}
printf '\nexit: %s\nsession_id: %s\n' "$codex_status" "$session_id"
printf 'last_message: %s\nlog: %s\n' "$out_dir/last.txt" "$out_dir/codex.log"
printf 'changed_files: %s (%s)\n' "$out_dir/changed_files.txt" "$changed_count"

if (( codex_status == 124 )) && [[ -n "$timeout_s" ]]; then
  unavailable "timed out after ${timeout_s}s"
elif (( codex_status == 127 )); then
  unavailable 'binary failed to launch (exit 127)'
elif (( codex_status != 0 )); then
  reason=$(tail -n 40 "$out_dir/codex.log" | grep -m1 -oiE \
    'spend cap|usage limit|quota|rate.?limit|429|401|unauthori[sz]ed|login|expired|5[0-9][0-9] [A-Za-z]|stream disconnected|connection (refused|reset)|network error' ||
    true)
  [[ -z "$reason" ]] || unavailable "$reason"
fi
exit "$codex_status"
