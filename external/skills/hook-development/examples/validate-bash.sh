#!/bin/bash
# Example PreToolUse hook for validating Bash commands (Codex)
# Demonstrates command validation patterns

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract command
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Validate command exists
if [ -z "$command" ]; then
  exit 0
fi

# Quick allowlist
if [[ "$command" =~ ^(ls|pwd|echo|date|whoami)(\s|$) ]]; then
  exit 0
fi

# Destructive operations
if [[ "$command" == *"rm -rf"* ]] || [[ "$command" == *"rm -fr"* ]]; then
  echo '{"decision": "deny", "reason": "Dangerous command detected: rm -rf"}' >&2
  exit 2
fi

# Other risky commands
if [[ "$command" == *"dd if="* ]] || [[ "$command" == *"mkfs"* ]] || [[ "$command" == *"> /dev/"* ]]; then
  echo '{"decision": "deny", "reason": "Dangerous system operation detected"}' >&2
  exit 2
fi

# Privilege escalation
if [[ "$command" == sudo* ]] || [[ "$command" == su* ]]; then
  echo '{"decision": "ask", "reason": "Command requires elevated privileges"}' >&2
  exit 2
fi

# Approve
exit 0
