#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
summarizer="$script_dir/summarize_time_profile.py"

usage() {
  cat <<'EOF'
Usage:
  time_profiler.sh attach <process-or-pid> [options]
  time_profiler.sh launch [options] -- <command...>
  time_profiler.sh summarize <trace-path> [options]

Options:
  --time-limit <value>       Capture duration, default: 10s
  --template <name>          Instruments template, default: Time Profiler
  --output <path>            Trace output path
  --summary-output <path>    Write markdown summary to a file
  --focus-process <name>     Treat this binary name as app-owned in the summary
  --top-frames <count>       Number of hotspot rows to include, default: 12
  --run-number <number>      Specific run number to summarize
  --trace-only               Record the trace but skip the summary step
  -h, --help                 Show this help text

Examples:
  time_profiler.sh attach PerformanceDashboard --time-limit 15s
  time_profiler.sh launch --focus-process PerformanceDashboard --time-limit 15s -- .build/staging/PerformanceDashboard.app/Contents/MacOS/PerformanceDashboard
  time_profiler.sh summarize /tmp/profile.trace --top-frames 10
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

resolve_launch_executable() {
  local executable="$1"
  if [[ "$executable" == */* ]]; then
    printf '%s\n' "$executable"
    return 0
  fi

  local resolved
  resolved="$(command -v "$executable" 2>/dev/null || true)"
  if [[ -z "$resolved" ]]; then
    echo "Could not resolve launch executable: $executable" >&2
    exit 1
  fi
  printf '%s\n' "$resolved"
}

make_temp_trace_path() {
  local temp_dir
  temp_dir="$(mktemp -d /tmp/instruments-profile.XXXXXX)"
  printf '%s/profile.trace\n' "$temp_dir"
}

run_summary() {
  local trace_path="$1"
  shift
  local summary_cmd=(python3 "$summarizer" "$trace_path")
  if [[ -n "$top_frames" ]]; then
    summary_cmd+=(--top-frames "$top_frames")
  fi
  if [[ -n "$focus_process" ]]; then
    summary_cmd+=(--focus-process "$focus_process")
  fi
  if [[ -n "$summary_output" ]]; then
    summary_cmd+=(--output "$summary_output")
  fi
  if [[ -n "$run_number" ]]; then
    summary_cmd+=(--run-number "$run_number")
  fi
  "${summary_cmd[@]}"
}

require_command xcrun
require_command python3

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

mode="$1"
shift

time_limit="10s"
template="Time Profiler"
output=""
summary_output=""
focus_process=""
top_frames="12"
run_number=""
trace_only="0"

case "$mode" in
  attach)
    if [[ $# -eq 0 ]]; then
      usage
      exit 1
    fi
    target="$1"
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --time-limit) time_limit="$2"; shift 2 ;;
        --template) template="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --summary-output) summary_output="$2"; shift 2 ;;
        --focus-process) focus_process="$2"; shift 2 ;;
        --top-frames) top_frames="$2"; shift 2 ;;
        --run-number) run_number="$2"; shift 2 ;;
        --trace-only) trace_only="1"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
      esac
    done
    ;;
  launch)
    launch_command=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --time-limit) time_limit="$2"; shift 2 ;;
        --template) template="$2"; shift 2 ;;
        --output) output="$2"; shift 2 ;;
        --summary-output) summary_output="$2"; shift 2 ;;
        --focus-process) focus_process="$2"; shift 2 ;;
        --top-frames) top_frames="$2"; shift 2 ;;
        --run-number) run_number="$2"; shift 2 ;;
        --trace-only) trace_only="1"; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; launch_command=("$@"); break ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
      esac
    done
    if [[ ${#launch_command[@]} -eq 0 ]]; then
      echo "Launch mode requires a command after --" >&2
      exit 1
    fi
    resolved_launch_executable="$(resolve_launch_executable "${launch_command[0]}")"
    launch_command=("$resolved_launch_executable" "${launch_command[@]:1}")
    ;;
  summarize)
    if [[ $# -eq 0 ]]; then
      usage
      exit 1
    fi
    trace_path="$1"
    shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --summary-output|--output) summary_output="$2"; shift 2 ;;
        --focus-process) focus_process="$2"; shift 2 ;;
        --top-frames) top_frames="$2"; shift 2 ;;
        --run-number) run_number="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
      esac
    done
    run_summary "$trace_path"
    exit 0
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    usage
    exit 1
    ;;
esac

if [[ -z "$output" ]]; then
  output="$(make_temp_trace_path)"
fi

record_cmd=(xcrun xctrace record --quiet --template "$template" --output "$output" --time-limit "$time_limit" --no-prompt)

if [[ "$mode" == "attach" ]]; then
  record_cmd+=(--attach "$target")
else
  record_cmd+=(--launch -- "${launch_command[@]}")
fi

set +e
"${record_cmd[@]}"
record_status=$?
set -e

if [[ ! -e "$output" ]]; then
  exit "$record_status"
fi

if [[ "$record_status" -ne 0 ]]; then
  echo "xctrace exited with status $record_status but wrote $output; continuing." >&2
fi

echo "Trace file: $output"

# In launch mode xctrace may leave one or two PerformanceDashboard processes in
# a stopped (T) state:
#   1. The directly-launched binary tracked by xctrace (from the TOC PID).
#   2. A re-exec'd copy that macOS/AppKit spawns when it finds the co-located
#      .build/staging app bundle — this second process is never tracked by
#      xctrace and so the TOC-based approach alone will not catch it.
# Kill both by first using the TOC PID and then sweeping for any remaining
# stopped PerformanceDashboard processes.
if [[ "$mode" == "launch" ]]; then
  launched_pid="$(xcrun xctrace export --input "$output" --toc --quiet 2>/dev/null \
    | sed -n 's/.*<process[^>]*type="launched"[^>]*pid="\([0-9]*\)".*/\1/p' | head -1)"
  if [[ -n "$launched_pid" ]] && ps -p "$launched_pid" >/dev/null 2>&1; then
    echo "Killing launched process (pid $launched_pid) left by xctrace…" >&2
    kill -CONT "$launched_pid" 2>/dev/null || true
    kill -TERM "$launched_pid" 2>/dev/null || true
  fi
  # Sweep for any additional stopped PerformanceDashboard processes (the
  # re-exec'd staging-bundle copy that xctrace does not track).
  while IFS= read -r stuck_pid; do
    [[ -z "$stuck_pid" ]] && continue
    echo "Killing orphaned stopped process (pid $stuck_pid) left by staging re-exec…" >&2
    kill -CONT "$stuck_pid" 2>/dev/null || true
    kill -TERM "$stuck_pid" 2>/dev/null || true
  done < <(ps -Ao pid=,stat=,comm= | awk '$2 ~ /^T/ && $3 ~ /PerformanceDashboard/ {print $1}')
fi

if [[ "$trace_only" == "1" ]]; then
  exit 0
fi

run_summary "$output"