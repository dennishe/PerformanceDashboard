#!/usr/bin/env bash
# PostToolUse hook — sets a sentinel flag when the agent edits source files.
# Called with tool invocation JSON on stdin.
set -euo pipefail

INPUT=$(cat)

# Extract the tool name from the hook JSON payload.
TOOL=$(printf '%s' "$INPUT" | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(d.get('toolName',''))" 2>/dev/null || true)

case "$TOOL" in
  replace_string_in_file|multi_replace_string_in_file|create_file|edit_notebook_file)
    touch /tmp/.pd_code_changed
    ;;
esac

exit 0
