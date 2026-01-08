#!/bin/bash
# Hook Schema Validator (Codex)
# Validates hooks.json structure and checks for common issues

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <path/to/hooks.json>"
  echo ""
  echo "Validates hook configuration file for:"
  echo "  - Valid JSON syntax"
  echo "  - Required fields"
  echo "  - Hook event validity"
  echo "  - Matcher patterns"
  echo "  - Timeout ranges"
  exit 1
fi

HOOKS_FILE="$1"

if [ ! -f "$HOOKS_FILE" ]; then
  echo "❌ Error: File not found: $HOOKS_FILE"
  exit 1
fi

echo "🔍 Validating hooks configuration: $HOOKS_FILE"
echo ""

# Check 1: Valid JSON
echo "Checking JSON syntax..."
if ! jq empty "$HOOKS_FILE" 2>/dev/null; then
  echo "❌ Invalid JSON syntax"
  exit 1
fi
echo "✅ Valid JSON"

# Determine root (supports {"hooks": {...}} or direct)
ROOT="."
if jq -e '.hooks' "$HOOKS_FILE" >/dev/null 2>&1; then
  ROOT=".hooks"
fi

# Check 2: Root structure
echo ""
echo "Checking root structure..."
VALID_EVENTS=("SessionStart" "UserPromptSubmit" "PreToolUse" "PostToolUse" "Stop" "SessionEnd" "SubagentStop")

for event in $(jq -r "$ROOT | keys[]" "$HOOKS_FILE"); do
  found=false
  for valid_event in "${VALID_EVENTS[@]}"; do
    if [ "$event" = "$valid_event" ]; then
      found=true
      break
    fi
  done

  if [ "$found" = false ]; then
    echo "⚠️  Unknown event type: $event"
  fi
done
echo "✅ Root structure valid"

# Check 3: Validate each hook
echo ""
echo "Validating individual hooks..."

error_count=0
warning_count=0
# shellcheck disable=SC2016
literal_hook_root='${CODEX_HOOK_ROOT}'

for event in $(jq -r "$ROOT | keys[]" "$HOOKS_FILE"); do
  hook_count=$(jq -r "$ROOT.\"$event\" | length" "$HOOKS_FILE")

  for ((i=0; i<hook_count; i++)); do
    matcher=$(jq -r "$ROOT.\"$event\"[$i].matcher // empty" "$HOOKS_FILE")
    if [ -z "$matcher" ]; then
      echo "❌ ${event}[$i]: Missing 'matcher' field"
      error_count=$((error_count + 1))
      continue
    fi

    hooks=$(jq -r "$ROOT.\"$event\"[$i].hooks // empty" "$HOOKS_FILE")
    if [ -z "$hooks" ] || [ "$hooks" = "null" ]; then
      echo "❌ ${event}[$i]: Missing 'hooks' array"
      error_count=$((error_count + 1))
      continue
    fi

    hook_array_count=$(jq -r "$ROOT.\"$event\"[$i].hooks | length" "$HOOKS_FILE")

    for ((j=0; j<hook_array_count; j++)); do
      hook_type=$(jq -r "$ROOT.\"$event\"[$i].hooks[$j].type // empty" "$HOOKS_FILE")

      if [ -z "$hook_type" ]; then
        echo "❌ ${event}[$i].hooks[$j]: Missing 'type' field"
        error_count=$((error_count + 1))
        continue
      fi

      if [ "$hook_type" != "command" ] && [ "$hook_type" != "prompt" ]; then
        echo "❌ ${event}[$i].hooks[$j]: Invalid type '$hook_type' (must be 'command' or 'prompt')"
        error_count=$((error_count + 1))
        continue
      fi

      if [ "$hook_type" = "command" ]; then
        command=$(jq -r "$ROOT.\"$event\"[$i].hooks[$j].command // empty" "$HOOKS_FILE")
        if [ -z "$command" ]; then
          echo "❌ ${event}[$i].hooks[$j]: Command hooks must have 'command' field"
          error_count=$((error_count + 1))
        else
          if [[ "$command" == /* ]] && [[ "$command" != *"$literal_hook_root"* ]]; then
            echo "⚠️  ${event}[$i].hooks[$j]: Hardcoded absolute path detected. Consider using \${CODEX_HOOK_ROOT}"
            warning_count=$((warning_count + 1))
          fi
        fi
      else
        prompt=$(jq -r "$ROOT.\"$event\"[$i].hooks[$j].prompt // empty" "$HOOKS_FILE")
        if [ -z "$prompt" ]; then
          echo "❌ ${event}[$i].hooks[$j]: Prompt hooks must have 'prompt' field"
          error_count=$((error_count + 1))
        fi

        if [ "$event" != "Stop" ] && [ "$event" != "SubagentStop" ] && [ "$event" != "UserPromptSubmit" ] && [ "$event" != "PreToolUse" ]; then
          echo "⚠️  ${event}[$i].hooks[$j]: Prompt hooks are best on Stop, SubagentStop, UserPromptSubmit, PreToolUse"
          warning_count=$((warning_count + 1))
        fi
      fi

      timeout=$(jq -r "$ROOT.\"$event\"[$i].hooks[$j].timeout // empty" "$HOOKS_FILE")
      if [ -n "$timeout" ] && [ "$timeout" != "null" ]; then
        if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
          echo "❌ ${event}[$i].hooks[$j]: Timeout must be a number"
          error_count=$((error_count + 1))
        elif [ "$timeout" -gt 600 ]; then
          echo "⚠️  ${event}[$i].hooks[$j]: Timeout $timeout seconds is very high (max 600s)"
          warning_count=$((warning_count + 1))
        elif [ "$timeout" -lt 5 ]; then
          echo "⚠️  ${event}[$i].hooks[$j]: Timeout $timeout seconds is very low"
          warning_count=$((warning_count + 1))
        fi
      fi
    done
  done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $error_count -eq 0 ] && [ $warning_count -eq 0 ]; then
  echo "✅ All checks passed!"
  exit 0
elif [ $error_count -eq 0 ]; then
  echo "⚠️  Validation passed with $warning_count warning(s)"
  exit 0
else
  echo "❌ Validation failed with $error_count error(s) and $warning_count warning(s)"
  exit 1
fi
