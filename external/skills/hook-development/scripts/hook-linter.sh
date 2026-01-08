#!/bin/bash
# Hook Linter (Codex)
# Checks hook scripts for common issues and best practices

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <hook-script.sh> [hook-script2.sh ...]"
  echo ""
  echo "Checks hook scripts for:"
  echo "  - Shebang presence"
  echo "  - set -euo pipefail usage"
  echo "  - Input reading from stdin"
  echo "  - Proper error handling"
  echo "  - Variable quoting"
  echo "  - Exit code usage"
  echo "  - Hardcoded paths"
  echo "  - Timeout considerations"
  exit 1
fi

check_script() {
  local script="$1"
  local warnings=0
  local errors=0

  echo "🔍 Linting: $script"
  echo ""

  if [ ! -f "$script" ]; then
    echo "❌ Error: File not found"
    return 1
  fi

  if [ ! -x "$script" ]; then
    echo "⚠️  Not executable (chmod +x $script)"
    warnings=$((warnings + 1))
  fi

  first_line=$(head -1 "$script")
  if [[ ! "$first_line" =~ ^#!/ ]]; then
    echo "❌ Missing shebang (#!/bin/bash)"
    errors=$((errors + 1))
  fi

  if ! grep -q "set -euo pipefail" "$script"; then
    echo "⚠️  Missing 'set -euo pipefail' (recommended for safety)"
    warnings=$((warnings + 1))
  fi

  if ! grep -q "cat\|read" "$script"; then
    echo "⚠️  Doesn't appear to read input from stdin"
    warnings=$((warnings + 1))
  fi

  if grep -q "tool_input\|tool_name" "$script" && ! grep -q "jq" "$script"; then
    echo "⚠️  Parses hook input but doesn't use jq"
    warnings=$((warnings + 1))
  fi

  if grep -E '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$script" | grep -v '#' | grep -q .; then
    echo "⚠️  Potentially unquoted variables detected (injection risk)"
    echo "   Always use double quotes: \"\$variable\" not \$variable"
    warnings=$((warnings + 1))
  fi

  if grep -E '^[^#]*/home/|^[^#]*/usr/|^[^#]*/opt/' "$script" | grep -q .; then
    echo "⚠️  Hardcoded absolute paths detected"
    echo "   Use \$CODEX_PROJECT_ROOT or \$CODEX_HOOK_ROOT"
    warnings=$((warnings + 1))
  fi

  if ! grep -q "CODEX_HOOK_ROOT\|CODEX_PROJECT_ROOT" "$script"; then
    echo "💡 Tip: Use \$CODEX_HOOK_ROOT for hook-relative paths"
  fi

  if ! grep -q "exit 0\|exit 2" "$script"; then
    echo "⚠️  No explicit exit codes (should exit 0 or 2)"
    warnings=$((warnings + 1))
  fi

  if grep -q "PreToolUse\|Stop" "$script"; then
    if ! grep -q "decision\|permissionDecision" "$script"; then
      echo "💡 Tip: PreToolUse/Stop hooks should output decision JSON"
    fi
  fi

  if grep -E 'sleep [0-9]{3,}|while true' "$script" | grep -v '#' | grep -q .; then
    echo "⚠️  Potentially long-running code detected"
    echo "   Hooks should complete quickly (< 60s)"
    warnings=$((warnings + 1))
  fi

  if grep -q 'echo.*".*error\|Error\|denied\|Denied' "$script"; then
    if ! grep -q '>&2' "$script"; then
      echo "⚠️  Error messages should be written to stderr (>&2)"
      warnings=$((warnings + 1))
    fi
  fi

  if ! grep -q "if.*empty\|if.*null\|if.*-z" "$script"; then
    echo "💡 Tip: Consider validating input fields aren't empty"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "✅ No issues found"
    return 0
  elif [ $errors -eq 0 ]; then
    echo "⚠️  Found $warnings warning(s)"
    return 0
  else
    echo "❌ Found $errors error(s) and $warnings warning(s)"
    return 1
  fi
}

echo "🔎 Hook Script Linter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

total_errors=0

for script in "$@"; do
  if ! check_script "$script"; then
    total_errors=$((total_errors + 1))
  fi
  echo ""
done

if [ $total_errors -eq 0 ]; then
  echo "✅ All scripts passed linting"
  exit 0
else
  echo "❌ $total_errors script(s) had errors"
  exit 1
fi
