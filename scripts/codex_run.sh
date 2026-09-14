#!/usr/bin/env bash
# Safe wrapper for delegating work to Codex. ACCRE needs sandbox network access:
# otherwise bwrap cannot create its disabled-network namespace and misleadingly
# reports "No space left on device"; workspace-write still blocks outside writes.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: codex_run.sh [options] (PROMPT | -)
  --role code|think|search   default: code
  --model M                  override the role's model
  --effort E                 low|medium|high|xhigh|max|ultra
  --cd DIR                   working directory (default: $PWD; must exist)
  --out DIR                  output directory (default: ${TMPDIR:-/tmp}/codex_runs/...)
  --resume SESSION_ID        continue an existing session
  --dry-run                  print the fully quoted command and exit
  -h, --help                 show this help

PROMPT of "-" reads the prompt from stdin.
EOF
}

die_usage() {
  printf 'codex_run.sh: %s\nTry codex_run.sh --help for usage.\n' "$1" >&2
  exit 2
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
  exit 1
}

role=code model_override= effort_override= out_dir= resume_id= prompt=
work_dir=$PWD
dry_run=0 have_prompt=0 role_set=0 model_set=0 resume_set=0
for raw_arg in "$@"; do
  case $raw_arg in
    --dangerously-bypass-approvals-and-sandbox|danger-full-access)
      die_usage "forbidden argument: $raw_arg" ;;
  esac
done
while (( $# )); do
  case $1 in
    --role|--model|--effort|--cd|--out|--resume)
      option=$1
      (( $# >= 2 )) || die_usage "$option requires a value"
      case $option in
        --role) role=$2; role_set=1 ;; --model) model_override=$2; model_set=1 ;;
        --effort) effort_override=$2 ;; --cd) work_dir=$2 ;;
        --out) out_dir=$2 ;; --resume) resume_id=$2; resume_set=1 ;;
      esac
      shift 2 ;;
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
work_dir=$(cd "$work_dir" && pwd -P)

search_flag=0
case $role in
  code) model=${CODEX_CODE_MODEL:-gpt-5.6-sol}; effort=${CODEX_CODE_EFFORT:-high} ;;
  think) model=${CODEX_THINK_MODEL:-gpt-6-astra}; effort=${CODEX_THINK_EFFORT:-xhigh} ;;
  search)
    model=${CODEX_SEARCH_MODEL:-gpt-5.6-terra}
    effort=${CODEX_SEARCH_EFFORT:-max}; search_flag=1 ;;
  *) die_usage "bad role: $role" ;;
esac
[[ -n "$model_override" ]] && model=$model_override
[[ -n "$effort_override" ]] && effort=$effort_override
[[ -n "$model" ]] || die_usage 'model must not be empty'
case $effort in low|medium|high|xhigh|max|ultra) ;; *) die_usage "bad effort: $effort" ;; esac

if [[ -z "$out_dir" ]]; then
  out_parent=${TMPDIR:-/tmp}/codex_runs
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

codex_bin=$(discover_codex)
declare -a command=("$codex_bin")
(( search_flag )) && command+=(--search)
if [[ -n "$resume_id" ]]; then
  command+=(exec resume --skip-git-repo-check "$resume_id" -m "$model"
    -c "model_reasoning_effort=\"$effort\""
    -c 'sandbox_mode="workspace-write"'
    -c sandbox_workspace_write.network_access=true
    -o "$out_dir/last.txt" "$prompt")
else
  command+=(exec --skip-git-repo-check -C "$work_dir" -m "$model"
    -c "model_reasoning_effort=\"$effort\""
    -s workspace-write -c sandbox_workspace_write.network_access=true
    -o "$out_dir/last.txt" "$prompt")
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
set +e
if [[ $prompt == - ]]; then
  (run_command) >>"$out_dir/codex.log" 2>&1
else
  (run_command) </dev/null >>"$out_dir/codex.log" 2>&1
fi
codex_status=$?
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
printf 'exit: %s\nsession_id: %s\n' "$codex_status" "$session_id"
printf 'last_message: %s\nlog: %s\n' "$out_dir/last.txt" "$out_dir/codex.log"
printf 'changed_files: %s (%s)\n' "$out_dir/changed_files.txt" "$changed_count"
exit "$codex_status"
