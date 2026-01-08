#!/bin/bash
# Example PreToolUse hook for validating Write/Edit operations (Codex)
# Demonstrates file write validation patterns

set -euo pipefail

# Read input from stdin
input=$(cat)

# Extract file path
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Validate path exists
if [ -z "$file_path" ]; then
  exit 0
fi

# Path traversal
if [[ "$file_path" == *".."* ]]; then
  echo '{"decision": "deny", "reason": "Path traversal detected"}' >&2
  exit 2
fi

# System directories
if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /sys/* ]] || [[ "$file_path" == /usr/* ]]; then
  echo '{"decision": "deny", "reason": "Write to system directory blocked"}' >&2
  exit 2
fi

# Sensitive files
if [[ "$file_path" == *.env ]] || [[ "$file_path" == *secret* ]] || [[ "$file_path" == *credentials* ]]; then
  echo '{"decision": "ask", "reason": "Potentially sensitive file"}' >&2
  exit 2
fi

# Approve
exit 0
