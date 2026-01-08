#!/bin/bash
# Agent Card Validator
# Validates Codex agent card markdown files for structure and content

set -euo pipefail

# Usage
if [ $# -eq 0 ]; then
  echo "Usage: $0 <path/to/agent.md>"
  echo ""
  echo "Validates agent card for:"
  echo "  - YAML frontmatter structure"
  echo "  - Required fields (name, description)"
  echo "  - Optional fields sanity (profile, model, sandbox_mode, approval_policy)"
  echo "  - Prompt body presence and length"
  exit 1
fi

AGENT_FILE="$1"

echo "🔍 Validating agent card: $AGENT_FILE"
echo ""

# Check 1: File exists
if [ ! -f "$AGENT_FILE" ]; then
  echo "❌ File not found: $AGENT_FILE"
  exit 1
fi
echo "✅ File exists"

# Check 2: Starts with ---
FIRST_LINE=$(head -1 "$AGENT_FILE")
if [ "$FIRST_LINE" != "---" ]; then
  echo "❌ File must start with YAML frontmatter (---)"
  exit 1
fi
echo "✅ Starts with frontmatter"

# Check 3: Has closing ---
if ! tail -n +2 "$AGENT_FILE" | grep -q '^---$'; then
  echo "❌ Frontmatter not closed (missing second ---)"
  exit 1
fi
echo "✅ Frontmatter properly closed"

# Extract frontmatter and prompt body
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$AGENT_FILE")
PROMPT_BODY=$(awk '/^---$/{i++; next} i>=2 {print}' "$AGENT_FILE")

get_field() {
  local key="$1"
  echo "$FRONTMATTER" | awk -F: -v key="$key" 'tolower($1)==key {sub(/^[^:]*:[ ]*/, "", $0); print; exit}' | sed 's/^ *//; s/ *$//; s/^"//; s/"$//'
}

# Check 4: Required fields
error_count=0
warning_count=0

echo ""
echo "Checking required fields..."

NAME=$(get_field "name")
if [ -z "$NAME" ]; then
  echo "❌ Missing required field: name"
  error_count=$((error_count + 1))
else
  echo "✅ name: $NAME"
  if ! [[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "❌ name should be kebab-case (lowercase letters, numbers, hyphens)"
    error_count=$((error_count + 1))
  fi
  name_length=${#NAME}
  if [ "$name_length" -lt 3 ]; then
    echo "❌ name too short (minimum 3 characters)"
    error_count=$((error_count + 1))
  elif [ "$name_length" -gt 50 ]; then
    echo "❌ name too long (maximum 50 characters)"
    error_count=$((error_count + 1))
  fi
fi

DESCRIPTION=$(get_field "description")
if [ -z "$DESCRIPTION" ]; then
  echo "❌ Missing required field: description"
  error_count=$((error_count + 1))
else
  desc_length=${#DESCRIPTION}
  echo "✅ description: ${desc_length} characters"
  if [ "$desc_length" -lt 10 ]; then
    echo "⚠️  description too short (minimum 10 characters recommended)"
    warning_count=$((warning_count + 1))
  elif [ "$desc_length" -gt 500 ]; then
    echo "⚠️  description long (over 500 characters)"
    warning_count=$((warning_count + 1))
  fi
  if ! echo "$DESCRIPTION" | grep -qi 'use when'; then
    echo "💡 Tip: description should start with 'Use when...'"
  fi
fi

# Optional fields
PROFILE=$(get_field "profile")
MODEL=$(get_field "model")
SANDBOX_MODE=$(get_field "sandbox_mode")
APPROVAL_POLICY=$(get_field "approval_policy")
TOOLS=$(get_field "tools")

if [ -n "$PROFILE" ]; then
  echo "✅ profile: $PROFILE"
fi

if [ -n "$MODEL" ]; then
  echo "✅ model: $MODEL"
fi

if [ -n "$SANDBOX_MODE" ]; then
  case "$SANDBOX_MODE" in
    read-only|workspace-write|danger-full-access)
      echo "✅ sandbox_mode: $SANDBOX_MODE"
      ;;
    *)
      echo "⚠️  Unknown sandbox_mode: $SANDBOX_MODE"
      warning_count=$((warning_count + 1))
      ;;
  esac
fi

if [ -n "$APPROVAL_POLICY" ]; then
  case "$APPROVAL_POLICY" in
    untrusted|on-failure|on-request|never)
      echo "✅ approval_policy: $APPROVAL_POLICY"
      ;;
    *)
      echo "⚠️  Unknown approval_policy: $APPROVAL_POLICY"
      warning_count=$((warning_count + 1))
      ;;
  esac
fi

if [ -n "$TOOLS" ]; then
  echo "✅ tools: $TOOLS"
fi

# Check 5: Prompt body

echo ""
echo "Checking prompt body..."

if [ -z "$PROMPT_BODY" ]; then
  echo "❌ Prompt body is empty"
  error_count=$((error_count + 1))
else
  prompt_length=${#PROMPT_BODY}
  echo "✅ Prompt body: $prompt_length characters"

  if [ "$prompt_length" -lt 20 ]; then
    echo "❌ Prompt body too short (minimum 20 characters)"
    error_count=$((error_count + 1))
  elif [ "$prompt_length" -gt 12000 ]; then
    echo "⚠️  Prompt body very long (over 12,000 characters)"
    warning_count=$((warning_count + 1))
  fi

  if ! echo "$PROMPT_BODY" | grep -q "You are\|You will\|Your"; then
    echo "💡 Tip: consider second-person instructions (You are..., You will...)"
  fi
fi

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
