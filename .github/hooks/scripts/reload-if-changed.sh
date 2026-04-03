#!/usr/bin/env bash
# Stop hook — if the main agent made code changes this session,
# kill the running PerformanceDashboard process and relaunch via `swift run`.
# Exits silently when called from a subagent (no main-session marker).
set -euo pipefail

MAIN_MARKER=/tmp/.pd_is_main_agent
FLAG=/tmp/.pd_code_changed

# Only act when this is the main agent's Stop event.
if [[ ! -f "$MAIN_MARKER" ]]; then
  exit 0
fi
rm -f "$MAIN_MARKER"

if [[ ! -f "$FLAG" ]]; then
  exit 0
fi

rm -f "$FLAG"

# Kill any running instance (swift run launcher + the built executable).
pkill -f "PerformanceDashboard" 2>/dev/null || true
pkill -f "swift run" 2>/dev/null || true

# Brief grace period so the port/socket is released before relaunching.
sleep 0.5

# Launch the new build in the background so this hook exits promptly.
# stdout/stderr go to a log file for debugging.
nohup swift run \
  --package-path "$(dirname "$0")/../../.." \
  > /tmp/pd_run.log 2>&1 &

exit 0
