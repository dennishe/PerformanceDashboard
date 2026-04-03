#!/usr/bin/env bash
# UserPromptSubmit hook — marks this session as the main (user-facing) agent.
# Subagents are launched programmatically and never receive UserPromptSubmit,
# so this file will only exist in the main agent's session.
# Also clears any leftover code-changed flag from a previous session.
set -euo pipefail

touch /tmp/.pd_is_main_agent
rm -f /tmp/.pd_code_changed

exit 0
