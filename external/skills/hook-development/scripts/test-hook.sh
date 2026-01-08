#!/bin/bash
# Hook Testing Helper (Codex)
# Tests a hook with sample input and shows output

set -euo pipefail

# Usage
show_usage() {
  echo "Usage: $0 [options] <hook-script> <test-input.json>"
  echo ""
  echo "Options:"
  echo "  -h, --help      Show this help message"
  echo "  -v, --verbose   Show detailed execution information"
  echo "  -t, --timeout N Set timeout in seconds (default: 60)"
  echo ""
  echo "Examples:"
  echo "  $0 validate-bash.sh test-input.json"
  echo "  $0 -v -t 30 validate-write.sh write-input.json"
  echo ""
  echo "Creates sample test input with:"
  echo "  $0 --create-sample <event-type>"
  exit 0
}

# Create sample input
create_sample() {
  event_type="$1"

  case "$event_type" in
    PreToolUse)
      cat <<'JSON'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.txt",
  "cwd": "/tmp/test-project",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "event": "PreToolUse",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/tmp/test.txt",
    "content": "Test content"
  }
}
JSON
      ;;
    PostToolUse)
      cat <<'JSON'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.txt",
  "cwd": "/tmp/test-project",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "event": "PostToolUse",
  "hook_event_name": "PostToolUse",
  "tool_name": "Bash",
  "tool_result": {"stdout": "Command executed successfully"}
}
JSON
      ;;
    Stop|SubagentStop)
      cat <<'JSON'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.txt",
  "cwd": "/tmp/test-project",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "event": "Stop",
  "hook_event_name": "Stop",
  "reason": "Task appears complete"
}
JSON
      ;;
    UserPromptSubmit)
      cat <<'JSON'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.txt",
  "cwd": "/tmp/test-project",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "event": "UserPromptSubmit",
  "hook_event_name": "UserPromptSubmit",
  "user_prompt": "Test user prompt"
}
JSON
      ;;
    SessionStart|SessionEnd)
      cat <<'JSON'
{
  "session_id": "test-session",
  "transcript_path": "/tmp/transcript.txt",
  "cwd": "/tmp/test-project",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "event": "SessionStart",
  "hook_event_name": "SessionStart"
}
JSON
      ;;
    *)
      echo "Unknown event type: $event_type"
      echo "Valid types: PreToolUse, PostToolUse, Stop, SubagentStop, UserPromptSubmit, SessionStart, SessionEnd"
      exit 1
      ;;
  esac
}

# Parse arguments
VERBOSE=false
TIMEOUT=60

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_usage
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -t|--timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --create-sample)
      create_sample "$2"
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [ $# -ne 2 ]; then
  echo "Error: Missing required arguments"
  echo ""
  show_usage
fi

HOOK_SCRIPT="$1"
TEST_INPUT="$2"

# Validate inputs
if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "❌ Error: Hook script not found: $HOOK_SCRIPT"
  exit 1
fi

if [ ! -x "$HOOK_SCRIPT" ]; then
  echo "⚠️  Warning: Hook script is not executable. Attempting to run with bash..."
  HOOK_SCRIPT="bash $HOOK_SCRIPT"
fi

if [ ! -f "$TEST_INPUT" ]; then
  echo "❌ Error: Test input not found: $TEST_INPUT"
  exit 1
fi

if ! jq empty "$TEST_INPUT" 2>/dev/null; then
  echo "❌ Error: Test input is not valid JSON"
  exit 1
fi

echo "🧪 Testing hook: $HOOK_SCRIPT"
echo "📥 Input: $TEST_INPUT"
echo ""

if [ "$VERBOSE" = true ]; then
  echo "Input JSON:"
  jq . "$TEST_INPUT"
  echo ""
fi

# Set up environment
export CODEX_PROJECT_ROOT="${CODEX_PROJECT_ROOT:-/tmp/test-project}"
export CODEX_HOOK_ROOT="${CODEX_HOOK_ROOT:-$(pwd)}"
export CODEX_ENV_FILE="${CODEX_ENV_FILE:-/tmp/test-env-$$}"

if [ "$VERBOSE" = true ]; then
  echo "Environment:"
  echo "  CODEX_PROJECT_ROOT=$CODEX_PROJECT_ROOT"
  echo "  CODEX_HOOK_ROOT=$CODEX_HOOK_ROOT"
  echo "  CODEX_ENV_FILE=$CODEX_ENV_FILE"
  echo ""
fi

# Run the hook
echo "▶️  Running hook (timeout: ${TIMEOUT}s)..."
echo ""

start_time=$(date +%s)

set +e
output=$(timeout "$TIMEOUT" bash -c "cat '$TEST_INPUT' | $HOOK_SCRIPT" 2>&1)
exit_code=$?
set -e

end_time=$(date +%s)
duration=$((end_time - start_time))

# Analyze results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results:"
echo ""
echo "Exit code: $exit_code"
echo "Duration: ${duration}s"

echo ""
echo "Output:"
if [ -n "$output" ]; then
  echo "$output"
else
  echo "(no output)"
fi

echo ""

# Interpret exit codes
case "$exit_code" in
  0)
    echo "✅ Hook allowed the operation"
    ;;
  2)
    echo "⛔ Hook blocked the operation"
    ;;
  124)
    echo "⏱️  Hook timed out"
    ;;
  *)
    echo "⚠️  Hook exited with unexpected code: $exit_code"
    ;;
  esac

echo ""

# Validate output JSON if present
if [ -n "$output" ] && echo "$output" | jq empty >/dev/null 2>&1; then
  echo "✅ Output is valid JSON"
  if [ "$VERBOSE" = true ]; then
    echo "Parsed JSON:"
    echo "$output" | jq .
  fi
fi
