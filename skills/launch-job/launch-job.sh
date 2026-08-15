#!/usr/bin/env bash
# launch-job — scaffold and gate laptop-local launchd jobs. Invoked by the /launch-job skill.
#
#   launch-job.sh setup [--dir <path>] [--force]
#       Lay the foundations in <path>: bin/jobctl, lib/common.sh, Makefile, .gitignore,
#       ~/.cache/jobs, git init. Idempotent — re-run it any time. A foundation file that
#       has drifted from the template is reported, never overwritten, unless --force.
#
#   launch-job.sh new <name> --repo <path> --command "<cmd>" (--every <seconds> | --at HH:MM)
#                          [--dir <path>] [--notify] [--timeout <budget>]
#                          [--preflight "<cmd>"] [--env NAME[,NAME...]]
#       Scaffold one job folder: run.sh, <prefix>.<name>.plist, optional env.required and
#       preflight.sh. Then gate it. Refuses if the job already exists.
#
#   launch-job.sh check [<name>...] [--dir <path>]
#       Gate a job (or every job) against the conventions. Exit 1 if any error.
#
#   launch-job.sh config [--dir <path>] [--prefix <com.foo>]
#       With flags, record them; without, print what is currently resolved and from where.
#
# Two settings, each owned where it actually belongs, so neither has to be repeated:
#
#   dir           which jobs repo this device uses. A property of the DEVICE, so it lives in
#                 ~/.config/launch-job/config. Set it once (`setup --dir <path>`) and every
#                 later command finds it. A --dir flag overrides for one run.
#   label_prefix  the reverse-DNS prefix of every plist Label here (com.<prefix>.<job>). A
#                 property of the REPO — the jobs already in it must all agree — so it lives in
#                 <dir>/.launch-job. Absent, it is read off an existing plist, else defaults to
#                 com.jobs.
#
# Every check here exists because the shape it catches has already cost something: a plist
# whose Label disagrees with its filename is unmanageable by jobctl; `status=$?` in zsh
# silently disables a job's entire failure path; `exec` in a job that notifies replaces the
# shell that would have done the notifying; a run.sh pointed into a worktree dies the day
# `lgtm` removes it. The conventions are owned by the jobs repo's own CLAUDE.md — this
# enforces their mechanical subset.

set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEMPLATE="$SELF_DIR/template"

log()  { echo "launch-job: $*" >&2; }
die()  { echo "launch-job: error: $*" >&2; exit 2; }
fail() { echo "  ERROR $*" >&2; errors=$((errors + 1)); }
warn() { echo "  warn  $*" >&2; }

mode="${1:-}"; shift || true
[ -n "$mode" ] || die "usage: launch-job.sh setup|new|check|config ..."

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/launch-job/config"
setting() {
  [ -f "$1" ] || return 0
  sed -n "s|^$2=||p" "$1" | tail -1
}

dir=""; dir_source=""
name=""; repo=""; command_line=""; preflight_command=""; env_names=""
every=""; at=""; timeout_budget="30m"; use_notify=false; force=false
prefix=""; prefix_flag=""
positional=()

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)    prefix="${2:-}"; prefix_flag="${2:-}"; shift 2 ;;
    --dir)       dir="${2:-}"; dir_source="--dir"; shift 2 ;;
    --repo)      repo="${2:-}"; shift 2 ;;
    --command)   command_line="${2:-}"; shift 2 ;;
    --preflight) preflight_command="${2:-}"; shift 2 ;;
    --env)       env_names="${2:-}"; shift 2 ;;
    --every)     every="${2:-}"; shift 2 ;;
    --at)        at="${2:-}"; shift 2 ;;
    --timeout)   timeout_budget="${2:-}"; shift 2 ;;
    --notify)    use_notify=true; shift ;;
    --force)     force=true; shift ;;
    -*)          die "unknown argument: $1" ;;
    *)           positional+=("$1"); shift ;;
  esac
done

if [ -z "$dir" ] && [ ${#positional[@]} -gt 0 ] && [ "$mode" = setup ]; then
  dir="${positional[0]}"; dir_source="argument"
fi
if [ -z "$dir" ]; then
  dir=$(setting "$CONFIG" dir)
  [ -n "$dir" ] && dir_source="$CONFIG"
fi
[ -n "$dir" ] || die "no jobs directory known — name it once and every later command finds it:
      launch-job.sh setup --dir <path>"
dir="${dir%/}"

# The label prefix belongs to the repo. Read what is already there before falling back, so a
# repo built under an older convention still gates correctly.
pinned=$(setting "$dir/.launch-job" label_prefix)

# A flag must never quietly contradict what the repo has pinned. Scaffolding against a one-off
# --prefix would pass its own gate — the gate would be judging the job by the same flag that
# built it — and the disagreement would only surface on some later check that omitted the flag.
if [ -n "$prefix_flag" ] && [ -n "$pinned" ] && [ "$prefix_flag" != "$pinned" ] && [ "$mode" != setup ]; then
  die "$dir pins label_prefix=$pinned, but --prefix $prefix_flag was given.
  Every job in a repo shares one prefix. To change it deliberately:
      launch-job.sh setup --dir $dir --prefix $prefix_flag"
fi

[ -n "$prefix" ] || prefix="$pinned"

# Nothing pinned: read the prefix off the jobs already here. Disagreement between them is the
# defect itself — picking one would blame whichever job happened to sort second.
if [ -z "$prefix" ]; then
  found=""
  for existing in "$dir"/*/com.*.plist; do
    [ -e "$existing" ] || continue
    candidate=$(basename "$existing" .plist)
    candidate="${candidate%.*}"
    case " $found " in *" $candidate "*) ;; *) found="$found $candidate" ;; esac
  done
  # shellcheck disable=SC2086
  set -- $found
  [ $# -gt 1 ] && die "the jobs in $dir disagree on the label prefix ($found) — pin the right one:
      launch-job.sh setup --dir $dir --prefix <com.foo>"
  prefix="${1:-}"
fi
[ -n "$prefix" ] || prefix="com.jobs"

if [ "$mode" = config ]; then
  if [ "$dir_source" = "--dir" ] || [ -n "${positional[0]:-}" ]; then
    mkdir -p "$(dirname "$CONFIG")"
    printf 'dir=%s\n' "$dir" > "$CONFIG"
    log "recorded dir=$dir in $CONFIG"
  fi
  prefix_source="<dir>/.launch-job"
  if [ -n "$prefix_flag" ] && [ -d "$dir" ]; then
    printf 'label_prefix=%s\n' "$prefix" > "$dir/.launch-job"
    log "recorded label_prefix=$prefix in $dir/.launch-job"
  elif [ ! -f "$dir/.launch-job" ]; then
    prefix_source="read off an existing plist, else the default"
  fi
  echo "dir          $dir   ($dir_source)" >&2
  echo "label_prefix $prefix   ($prefix_source)" >&2
  exit 0
fi

# ---------------------------------------------------------------- setup

install_file() {
  local src="$1" dest="$2"
  if [ ! -f "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "created ${dest#$dir/}"
  elif cmp -s "$src" "$dest"; then
    log "unchanged ${dest#$dir/}"
  elif [ "$force" = true ]; then
    cp "$src" "$dest"
    log "OVERWROTE ${dest#$dir/} (--force)"
  else
    log "DRIFT ${dest#$dir/} differs from the template — left alone (--force to overwrite)"
  fi
}

if [ "$mode" = setup ]; then
  [ ${#positional[@]} -eq 0 ] || dir="${positional[0]%/}"
  log "foundations in $dir"
  mkdir -p "$dir/bin" "$dir/lib" "$HOME/.cache/jobs"
  install_file "$TEMPLATE/bin/jobctl"    "$dir/bin/jobctl"
  install_file "$TEMPLATE/lib/common.sh" "$dir/lib/common.sh"
  install_file "$TEMPLATE/Makefile"      "$dir/Makefile"
  install_file "$TEMPLATE/gitignore"     "$dir/.gitignore"
  chmod +x "$dir/bin/jobctl"
  if [ ! -d "$dir/.git" ]; then
    git -C "$dir" init --quiet
    log "git init"
  fi

  # Record both settings now, so nothing after this needs --dir or --prefix.
  mkdir -p "$(dirname "$CONFIG")"
  printf 'dir=%s\n' "$dir" > "$CONFIG"
  printf 'label_prefix=%s\n' "$prefix" > "$dir/.launch-job"
  log "recorded dir=$dir in $CONFIG, label_prefix=$prefix in $dir/.launch-job"
  log "done — add a job with: launch-job.sh new <name> ..."
  exit 0
fi

# ---------------------------------------------------------------- check

check_job() {
  local job="$1"
  local job_dir="$dir/$job" errors=0
  echo "$job:" >&2

  [ -d "$job_dir" ] || { fail "no such job folder: $job_dir"; return 1; }

  local plists=("$job_dir"/com.*.plist) plist
  if [ ! -e "${plists[0]}" ]; then
    fail "no com.*.plist in $job_dir"
    return 1
  fi
  [ ${#plists[@]} -eq 1 ] || fail "${#plists[@]} plists in $job_dir — jobctl expects exactly one"
  plist="${plists[0]}"

  local expected_label="$prefix.$job"
  [ "$(basename "$plist" .plist)" = "$expected_label" ] \
    || fail "plist is named $(basename "$plist") — the folder name is the job name, so it must be $expected_label.plist"

  if plutil -lint "$plist" >/dev/null 2>&1; then
    local label program out_path err_path
    label=$(plutil -extract Label raw -o - "$plist" 2>/dev/null || echo "")
    [ "$label" = "$expected_label" ] || fail "Label is '$label', expected '$expected_label' — jobctl derives everything from it"

    program=$(plutil -extract ProgramArguments.0 raw -o - "$plist" 2>/dev/null || echo "")
    case "$program" in
      /*) [ -x "$program" ] || fail "ProgramArguments[0] is not executable: $program" ;;
      *)  fail "ProgramArguments[0] must be an absolute path (launchd has no cwd): '$program'" ;;
    esac
    [ "$program" = "$job_dir/run.sh" ] || fail "ProgramArguments[0] is $program, expected $job_dir/run.sh"
    case "$program" in *.worktrees/*) fail "ProgramArguments[0] points into a worktree — it dies the day lgtm removes it" ;; esac

    out_path=$(plutil -extract StandardOutPath raw -o - "$plist" 2>/dev/null || echo "")
    err_path=$(plutil -extract StandardErrorPath raw -o - "$plist" 2>/dev/null || echo "")
    [ "$out_path" = "$HOME/.cache/jobs/$job.out" ] || fail "StandardOutPath is '$out_path', expected $HOME/.cache/jobs/$job.out"
    [ "$err_path" = "$HOME/.cache/jobs/$job.err" ] || fail "StandardErrorPath is '$err_path', expected $HOME/.cache/jobs/$job.err"

    local interval="" calendar=false keepalive=false schedules=0
    interval=$(plutil -extract StartInterval raw -o - "$plist" 2>/dev/null || echo "")
    plutil -extract StartCalendarInterval raw -o - "$plist" >/dev/null 2>&1 && calendar=true
    plutil -extract KeepAlive raw -o - "$plist" >/dev/null 2>&1 && keepalive=true
    [ -n "$interval" ] && schedules=$((schedules + 1))
    [ "$calendar" = true ] && schedules=$((schedules + 1))
    [ "$keepalive" = true ] && schedules=$((schedules + 1))
    [ "$schedules" -eq 1 ] || fail "expected exactly one of StartInterval / StartCalendarInterval / KeepAlive, found $schedules"

    # Slow cadence: silence is ambiguous for a day or more, so a failure has to push.
    local slow=false
    [ "$calendar" = true ] && slow=true
    [ -n "$interval" ] && [ "$interval" -ge 21600 ] 2>/dev/null && slow=true
    if [ "$slow" = true ] && ! grep -q "notify " "$job_dir/run.sh" 2>/dev/null; then
      warn "runs daily or slower but never calls notify — a dead job is indistinguishable from silence"
    fi
  else
    fail "plist is not valid: plutil -lint $plist"
  fi

  local run="$job_dir/run.sh"
  if [ ! -f "$run" ]; then
    fail "no run.sh"
  else
    [ -x "$run" ] || fail "run.sh is not executable (chmod +x)"

    grep -qE '^\s*while\s+(true|:)' "$run" \
      && fail "run.sh has an internal loop — a job is a one-shot; launchd owns the schedule"

    grep -qE '^\s*status=' "$run" \
      && fail "run.sh assigns \`status\` — zsh reserves it read-only, so this aborts between the command and the failure branch. Use exit_code"

    if grep -q "notify " "$run" && grep -qE '^\s*exec\s' "$run"; then
      fail "run.sh both execs and notifies — exec replaces the shell that would have sent the notification"
    fi

    grep -q "\.worktrees/" "$run" \
      && fail "run.sh references a worktree path — point at the root repo, worktrees get deleted"

    grep -qE '(^|[^-])\b(log|notify) ' "$run" && ! grep -q "lib/common.sh" "$run" \
      && fail "run.sh calls log/notify without sourcing lib/common.sh"

    if grep -q "notify " "$run" && ! grep -q "timeout " "$run"; then
      warn "notifies on failure but the run is unbounded — a hang never exits, so it never notifies. Wrap it in \`timeout\`"
    fi
    if grep -q "timeout " "$run"; then
      local caffeinate_call
      caffeinate_call=$(grep -m1 "caffeinate" "$run" || true)
      if [ -z "$caffeinate_call" ]; then
        warn "bounded but not caffeinated — on battery launchd's DarkWake window closes in ~45s and the run is stretched, not killed. Use \`caffeinate -is\`"
      elif ! printf '%s' "$caffeinate_call" | grep -qE '\-[a-z]*s'; then
        warn "caffeinate without -s — -i alone only defers idle sleep on an awake machine and does nothing to hold a DarkWake open"
      fi
    fi

    grep -q "TODO" "$run" && warn "run.sh still contains a TODO placeholder"
  fi

  [ -f "$job_dir/preflight.sh" ] && [ ! -x "$job_dir/preflight.sh" ] \
    && fail "preflight.sh is not executable (chmod +x)"

  if [ "$errors" -eq 0 ]; then
    echo "  ok" >&2
    return 0
  fi
  return 1
}

if [ "$mode" = check ]; then
  [ -d "$dir" ] || die "no jobs directory at $dir (run: launch-job.sh setup --dir $dir)"
  jobs=("${positional[@]:-}")
  if [ -z "${jobs[0]:-}" ]; then
    jobs=()
    for candidate in "$dir"/*/; do
      [ -e "${candidate}run.sh" ] && jobs+=("$(basename "$candidate")")
    done
  fi
  [ ${#jobs[@]} -gt 0 ] || die "no jobs found in $dir"
  failed=0
  for job in "${jobs[@]}"; do
    check_job "$job" || failed=$((failed + 1))
  done
  [ "$failed" -eq 0 ] || { log "$failed job(s) failed the gate"; exit 1; }
  log "all clear"
  exit 0
fi

# ---------------------------------------------------------------- new

[ "$mode" = new ] || die "unknown mode '$mode' (setup|new|check)"

name="${positional[0]:-}"
[ -n "$name" ] || die "usage: launch-job.sh new <name> --repo <path> --command \"<cmd>\" (--every <seconds> | --at HH:MM)"
[ -x "$dir/bin/jobctl" ] || die "$dir is not set up (run: launch-job.sh setup --dir $dir)"
[ -e "$dir/$name" ] && die "$dir/$name already exists"
[ -n "$repo" ] || die "--repo <path> is required: the root repo whose code this job runs"
[ -d "$repo" ] || die "--repo does not exist: $repo"
case "$repo" in *.worktrees/*) die "--repo points into a worktree — a job outlives worktrees; use the root repo" ;; esac
[ -n "$command_line" ] || die "--command \"<cmd>\" is required: what the wrapper execs in $repo"
[ -n "$every" ] || [ -n "$at" ] || die "give a cadence: --every <seconds> or --at HH:MM"
[ -n "$every" ] && [ -n "$at" ] && die "--every and --at are mutually exclusive"

if [ -n "$every" ]; then
  schedule=$(printf '    <!-- Every %s seconds. -->\n    <key>StartInterval</key>\n    <integer>%s</integer>' "$every" "$every")
else
  case "$at" in
    [0-9][0-9]:[0-9][0-9]) ;;
    *) die "--at must be HH:MM (24h), got '$at'" ;;
  esac
  hour=${at%%:*}; minute=${at##*:}
  schedule=$(printf '    <!-- Daily at %s. -->\n    <key>StartCalendarInterval</key>\n    <dict>\n        <key>Hour</key>\n        <integer>%s</integer>\n        <key>Minute</key>\n        <integer>%s</integer>\n    </dict>' "$at" "$((10#$hour))" "$((10#$minute))")
fi

job_dir="$dir/$name"
mkdir -p "$job_dir"

# A half-written folder would block the retry (`new` refuses an existing job), so unwind
# it on any failure below. Only ever the folder this run just created.
scaffold_complete=false
cleanup() { [ "$scaffold_complete" = true ] || { rm -rf "$job_dir"; log "removed the partial $job_dir"; }; }
trap cleanup EXIT

template_run="$TEMPLATE/job/run.sh"
[ "$use_notify" = true ] && template_run="$TEMPLATE/job/run-notify.sh"

render() {
  sed -e "s|__JOB__|$name|g" \
      -e "s|__LABEL__|$prefix.$name|g" \
      -e "s|__JOBS_DIR__|$dir|g" \
      -e "s|__HOME__|$HOME|g" \
      -e "s|__REPO__|$repo|g" \
      -e "s|__TIMEOUT__|$timeout_budget|g" \
      -e "s|__COMMAND__|$command_line|g" \
      -e "s|__PREFLIGHT_COMMAND__|$preflight_command|g" "$1"
}

render "$template_run" > "$job_dir/run.sh"
chmod +x "$job_dir/run.sh"

# The schedule block is multi-line, so it replaces its placeholder line by line.
while IFS= read -r line; do
  if [ "$line" = "__SCHEDULE__" ]; then printf '%s\n' "$schedule"; else printf '%s\n' "$line"; fi
done < <(render "$TEMPLATE/job/plist") > "$job_dir/$prefix.$name.plist"

if [ -n "$env_names" ]; then
  {
    echo "# Env vars this job needs but launchd won't have (no ~/.zshrc at tick time)."
    echo "# Captured from your interactive shell at \`make start\`, frozen, sourced each tick."
    echo "# One NAME per line; values live in your shell, never here."
    echo "$env_names" | tr ',' '\n' | sed '/^$/d'
  } > "$job_dir/env.required"
  log "wrote env.required"
fi

if [ -n "$preflight_command" ]; then
  render "$TEMPLATE/job/preflight.sh" > "$job_dir/preflight.sh"
  chmod +x "$job_dir/preflight.sh"
  log "wrote preflight.sh"
fi

log "created $job_dir"
check_job "$name" || die "the scaffold does not pass its own gate — fix the above"
scaffold_complete=true

cat >&2 <<NEXT
launch-job: next, from $dir
  1. edit $name/run.sh — replace the TODO header line
  2. make start JOB=$name    (freezes env, runs preflight, loads the agent)
  3. make run   JOB=$name    (force one run now)
  4. make tail  JOB=$name    (watch it)
NEXT
