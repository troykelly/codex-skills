#!/usr/bin/env bash
#
# plan-limit-account-switch.sh - Stop hook for detecting plan limits and switching accounts
#
# This hook intercepts Codex stop attempts and checks if the session ended
# due to plan/rate limit exhaustion. If so, it:
#   1. Switches to another available Codex account
#   2. Writes state files for codex-autonomous to detect
#   3. Sends SIGTERM to force Codex to exit (credentials are loaded at startup)
#   4. codex-autonomous then resumes with new credentials
#
# Part of the Ralph Wiggum-inspired autonomous operation pattern.
#
# Exit codes:
#   0 - Always exits 0, but may kill Codex process before exiting
#

set -euo pipefail

# Source shared libraries if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log-event.sh
if [[ -f "${SCRIPT_DIR}/lib/log-event.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/log-event.sh"
fi

# Codex home directory (defaults to ~/.codex)
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
EXHAUSTION_FILE="${CODEX_HOME}/.account-exhaustion.json"
STATE_DIR="${CODEX_HOME}"

# Configuration
COOLDOWN_MINUTES="${CODEX_ACCOUNT_COOLDOWN_MINUTES:-5}"
FLAP_THRESHOLD="${CODEX_ACCOUNT_FLAP_THRESHOLD:-3}"
FLAP_WINDOW_SECONDS="${CODEX_ACCOUNT_FLAP_WINDOW:-60}"

# Session-specific state files (to support multiple concurrent sessions)
# Uses CODEX_AUTONOMOUS_SESSION_ID if available, otherwise falls back to PID-based identifier
get_session_suffix() {
  if [[ -n "${CODEX_AUTONOMOUS_SESSION_ID:-}" ]]; then
    echo ".${CODEX_AUTONOMOUS_SESSION_ID}"
  elif [[ -n "${CODEX_SESSION_ID:-}" ]]; then
    echo ".${CODEX_SESSION_ID}"
  else
    # Fallback: use a hash of transcript path if available, otherwise empty
    # Empty suffix means global file (backwards compatible for non-autonomous usage)
    echo ""
  fi
}

resolve_codex_account_cmd() {
  if [[ -n "${CODEX_ACCOUNT_CMD:-}" ]] && [[ -x "${CODEX_ACCOUNT_CMD}" ]]; then
    echo "${CODEX_ACCOUNT_CMD}"
    return 0
  fi

  if command -v codex-account &>/dev/null; then
    command -v codex-account
    return 0
  fi

  return 1
}

# Plan limit detection patterns (case-insensitive)
# These patterns are designed to be SPECIFIC to Codex/OpenAI rate limiting
# and avoid false positives from normal conversation content.
#
# IMPORTANT: Patterns must NOT match our own hook output to prevent feedback loops!
# Our output contains "Plan limit reached" which would match "limit.?reached"
#
# We look for specific OpenAI/Codex API error signatures:
PLAN_LIMIT_PATTERNS=(
  # OpenAI/Codex API error messages
  "openai.*rate.?limit"
  "api.*rate.?limit"
  "rate.?limit"
  "quota"
  "usage.?limit"
  "plan.?limit"
  "subscription.*limit"
  "messages?.?limit.*exceeded"
  "exceeded.*messages?.?limit"
  "you.?have.?reached.*limit"
  "you.?ve.?hit.*limit"
  "hit.?your.?limit"
  "resets.*\\(UTC\\)"
  "usage.?cap"
  "insufficient_quota"
  "billing"
  "capacity"
  "try.?again.?later"
  # HTTP errors with API context (not just bare numbers)
  "api.*429"
  "429.*rate"
  "error.*429"
  "api.*503"
  "503.*overload"
  "overload"
  # Specific throttling contexts
  "api.*throttl"
  "request.*throttl"
)

# Patterns that indicate our OWN output (to exclude from matching)
SELF_OUTPUT_MARKERS=(
  "Plan limit reached on"
  "Plan limit on"
  "Switching to account:"
  "codex-account switch"
  "All accounts exhausted"
  "Entering SLEEP mode"
  "entering cooldown"
  "Codex must restart"
)

# Initialize exhaustion tracking file
init_exhaustion_file() {
  if [[ ! -f "${EXHAUSTION_FILE}" ]]; then
    mkdir -p "$(dirname "${EXHAUSTION_FILE}")"
    cat > "${EXHAUSTION_FILE}" << EOF
{
  "exhausted": {},
  "switches": [],
  "cooldown_minutes": ${COOLDOWN_MINUTES}
}
EOF
    chmod 600 "${EXHAUSTION_FILE}"
  fi
}

# Check if transcript contains plan limit indicators
detect_plan_limit() {
  local transcript_path="$1"

  if [[ ! -f "${transcript_path}" ]]; then
    return 1
  fi

  # Build combined regex pattern for detection
  local pattern=""
  for p in "${PLAN_LIMIT_PATTERNS[@]}"; do
    [[ -n "${pattern}" ]] && pattern="${pattern}|"
    pattern="${pattern}${p}"
  done

  # Build exclusion pattern for our own output (to prevent feedback loops)
  local exclude_pattern=""
  for p in "${SELF_OUTPUT_MARKERS[@]}"; do
    [[ -n "${exclude_pattern}" ]] && exclude_pattern="${exclude_pattern}|"
    exclude_pattern="${exclude_pattern}${p}"
  done

  # Search last 50 lines of transcript, excluding our own output
  # 1. Get last 50 lines
  # 2. Filter out lines containing our self-output markers
  # 3. Check remaining lines for plan limit patterns
  local filtered_content
  filtered_content=$(tail -50 "${transcript_path}" 2>/dev/null | grep -viE "${exclude_pattern}" || true)

  if [[ -z "${filtered_content}" ]]; then
    return 1
  fi

  if echo "${filtered_content}" | grep -qiE "${pattern}"; then
    return 0
  fi

  return 1
}

# Mark current account as exhausted
mark_exhausted() {
  local email="$1"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  init_exhaustion_file

  local tmp_file
  tmp_file=$(mktemp)
  # Use trap to clean up temp file on failure (expand now, not at signal time)
  # shellcheck disable=SC2064
  trap "rm -f '${tmp_file}'" RETURN

  if EMAIL="${email}" TS="${timestamp}" jq \
    '.exhausted[env.EMAIL] = env.TS' "${EXHAUSTION_FILE}" > "${tmp_file}" 2>/dev/null; then
    mv "${tmp_file}" "${EXHAUSTION_FILE}"
  else
    echo "Warning: Failed to mark account as exhausted" >&2
  fi
}

# Record an account switch (for flap detection)
record_switch() {
  local from_email="$1"
  local to_email="$2"
  local timestamp
  timestamp=$(date +%s)

  init_exhaustion_file

  local tmp_file
  tmp_file=$(mktemp)
  # Use trap to clean up temp file on failure (expand now, not at signal time)
  # shellcheck disable=SC2064
  trap "rm -f '${tmp_file}'" RETURN

  if FROM_EMAIL="${from_email}" TO_EMAIL="${to_email}" TS="${timestamp}" jq \
    '.switches += [{"from": env.FROM_EMAIL, "to": env.TO_EMAIL, "timestamp": (env.TS | tonumber)}] | .switches = (.switches | .[-20:])' \
    "${EXHAUSTION_FILE}" > "${tmp_file}" 2>/dev/null; then
    mv "${tmp_file}" "${EXHAUSTION_FILE}"
  else
    echo "Warning: Failed to record account switch" >&2
  fi
}

# Check if we're flapping (too many switches in short window)
is_flapping() {
  init_exhaustion_file

  local now threshold_time count
  now=$(date +%s)
  threshold_time=$((now - FLAP_WINDOW_SECONDS))

  # Handle jq failure gracefully - if we can't read the file, assume not flapping
  count=$(THRESHOLD="${threshold_time}" jq \
    '[.switches[] | select(.timestamp > (env.THRESHOLD | tonumber))] | length' "${EXHAUSTION_FILE}" 2>/dev/null) || count=0

  # Ensure count is numeric (default to 0 if empty or invalid)
  if ! [[ "${count}" =~ ^[0-9]+$ ]]; then
    count=0
  fi

  [[ "${count}" -ge "${FLAP_THRESHOLD}" ]]
}

# Check if an account has cooled down
is_cooled_down() {
  local email="$1"

  init_exhaustion_file

  local exhausted_at now cooldown_seconds
  exhausted_at=$(EMAIL="${email}" jq -r '.exhausted[env.EMAIL] // empty' "${EXHAUSTION_FILE}" 2>/dev/null) || exhausted_at=""

  if [[ -z "${exhausted_at}" ]]; then
    return 0  # Not exhausted, so "cooled down"
  fi

  # Convert ISO timestamp to epoch
  local exhausted_epoch
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    exhausted_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${exhausted_at}" +%s 2>/dev/null || echo 0)
  else
    exhausted_epoch=$(date -d "${exhausted_at}" +%s 2>/dev/null || echo 0)
  fi

  now=$(date +%s)
  cooldown_seconds=$((COOLDOWN_MINUTES * 60))

  [[ $((now - exhausted_epoch)) -ge ${cooldown_seconds} ]]
}

# Get next available account (not exhausted or cooled down)
get_next_available() {
  local current_email="$1"

  # Get list of all accounts from environment
  local accounts_list=""
  local var value
  while IFS='=' read -r var value; do
    if [[ "${var}" =~ ^CODEX_ACCOUNT_.*_EMAILADDRESS$ ]]; then
      value="${value//\"/}"
      if [[ -n "${value}" ]]; then
        [[ -n "${accounts_list}" ]] && accounts_list="${accounts_list},"
        accounts_list="${accounts_list}${value}"
      fi
    fi
  done < <(env)

  if [[ -z "${accounts_list}" ]]; then
    # Fallback: parse CODEX_ENV_FILE for saved accounts
    local env_file="${CODEX_ENV_FILE:-./.env}"
    if [[ -f "${env_file}" ]]; then
      while IFS='=' read -r var value; do
        if [[ "${var}" =~ ^CODEX_ACCOUNT_.*_EMAILADDRESS$ ]]; then
          value="${value//\"/}"
          if [[ -n "${value}" ]]; then
            [[ -n "${accounts_list}" ]] && accounts_list="${accounts_list},"
            accounts_list="${accounts_list}${value}"
          fi
        fi
      done < <(grep "^CODEX_ACCOUNT_.*_EMAILADDRESS=" "${env_file}" 2>/dev/null || true)
    fi
  fi

  if [[ -z "${accounts_list}" ]]; then
    return 1
  fi

  # Parse into array
  local emails=()
  IFS=',' read -ra emails <<< "${accounts_list}"

  # Find next available account (round-robin from current)
  local found_current=false
  local candidate=""

  # First pass: find accounts after current
  for email in "${emails[@]}"; do
    if [[ "${found_current}" == "true" ]]; then
      if [[ "${email}" != "${current_email}" ]] && is_cooled_down "${email}"; then
        candidate="${email}"
        break
      fi
    fi
    if [[ "${email}" == "${current_email}" ]]; then
      found_current=true
    fi
  done

  # Second pass: wrap around to beginning
  if [[ -z "${candidate}" ]]; then
    for email in "${emails[@]}"; do
      if [[ "${email}" == "${current_email}" ]]; then
        break
      fi
      if is_cooled_down "${email}"; then
        candidate="${email}"
        break
      fi
    done
  fi

  if [[ -n "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

# Get current account email from codex-account (if available)
get_current_email() {
  local codex_account_cmd=""
  codex_account_cmd=$(resolve_codex_account_cmd || true)

  if [[ -n "${codex_account_cmd}" ]]; then
    local output clean email
    output=$("${codex_account_cmd}" current 2>/dev/null || true)
    # shellcheck disable=SC2001
    clean=$(echo "${output}" | sed 's/\x1b\[[0-9;]*m//g')
    email=$(echo "${clean}" | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -1) || true
    echo "${email}"
  fi
}

# Terminate the Codex process by finding it and sending SIGTERM/SIGKILL
# Codex doesn't auto-exit on rate limits, so we force it to exit
terminate_codex() {
  local reason="${1:-rate limit}"
  local codex_pid=""

  # Method 1: Walk up the process tree from our PPID
  local check_pid="${PPID}"
  while [[ -n "${check_pid}" && "${check_pid}" != "1" ]]; do
    local proc_name
    proc_name=$(ps -p "${check_pid}" -o comm= 2>/dev/null || true)
    if [[ "${proc_name}" == "codex" ]]; then
      codex_pid="${check_pid}"
      break
    fi
    # Get parent of this process
    check_pid=$(ps -p "${check_pid}" -o ppid= 2>/dev/null | tr -d ' ' || true)
  done

  # Method 2: Fallback to pgrep if we didn't find it
  if [[ -z "${codex_pid}" ]]; then
    codex_pid=$(pgrep -x "codex" 2>/dev/null | head -1 || true)
  fi

  if [[ -n "${codex_pid}" ]]; then
    echo "Terminating Codex (PID ${codex_pid}) due to ${reason}..." >&2
    kill -TERM "${codex_pid}" 2>/dev/null || true
    # Give it a moment to clean up
    sleep 1
    # If still running, send SIGKILL
    if kill -0 "${codex_pid}" 2>/dev/null; then
      echo "Codex didn't exit cleanly, sending SIGKILL..." >&2
      kill -KILL "${codex_pid}" 2>/dev/null || true
    fi
  else
    echo "Could not find Codex process to terminate. Manual restart required." >&2
  fi
}

# Main hook logic
main() {
  # Read hook input from stdin
  local hook_input
  hook_input=$(cat)

  # Parse input (with fallbacks for malformed JSON)
  local transcript_path stop_hook_active
  transcript_path=$(echo "${hook_input}" | jq -r '.transcript_path // empty' 2>/dev/null) || transcript_path=""
  stop_hook_active=$(echo "${hook_input}" | jq -r '.stop_hook_active // false' 2>/dev/null) || stop_hook_active="false"

  # Prevent infinite loops - if stop_hook_active is true, we already blocked once
  if [[ "${stop_hook_active}" == "true" ]]; then
    # Check if we're flapping
    if is_flapping; then
      echo "All accounts appear exhausted. Entering cooldown." >&2
      exit 0
    fi
  fi

  # Check for plan limit indicators in transcript
  if [[ -n "${transcript_path}" ]] && detect_plan_limit "${transcript_path}"; then
    local current_email next_account
    current_email=$(get_current_email)

    if [[ -z "${current_email}" ]]; then
      # No current account info, can't switch
      exit 0
    fi

    # Mark current account as exhausted
    mark_exhausted "${current_email}"

    # Try to get next available account
    if next_account=$(get_next_available "${current_email}"); then
      # Record the switch for flap detection
      record_switch "${current_email}" "${next_account}"

      # Check for flapping before proceeding
      if is_flapping; then
        echo "Account switch flapping detected. All accounts may be exhausted. Entering cooldown." >&2
        exit 0
      fi

      # Perform the actual account switch NOW
      # Codex CLI must exit and restart to use new credentials (they're loaded at startup)
      local codex_account_cmd=""
      codex_account_cmd=$(resolve_codex_account_cmd || true)

      if [[ -n "${codex_account_cmd}" ]]; then
        # Switch account credentials - this updates ~/.codex/auth.json
        if "${codex_account_cmd}" switch "${next_account}" &>/dev/null; then
          echo "Plan limit on ${current_email}. Switched credentials to ${next_account}." >&2
          echo "Codex must restart to use new credentials. Use --resume to continue." >&2
        else
          echo "Failed to switch to ${next_account}. Manual intervention required." >&2
        fi
      else
        echo "codex-account not found. Manual switch required: codex-account switch ${next_account}" >&2
      fi

      # Write switch state for codex-autonomous to detect (session-specific)
      local session_suffix
      session_suffix=$(get_session_suffix)
      local switch_file="${STATE_DIR}/.pending-account-switch${session_suffix}"
      mkdir -p "$(dirname "${switch_file}")"
      if ! FROM_EMAIL="${current_email}" TO_EMAIL="${next_account}" TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" jq -n \
        '{from: env.FROM_EMAIL, to: env.TO_EMAIL, timestamp: env.TS, reason: "plan_limit"}' > "${switch_file}" 2>/dev/null; then
        echo "Warning: Failed to write switch state file" >&2
      fi

      # Force Codex to exit so it can restart with new credentials
      terminate_codex "account switch to ${next_account}"

      exit 0
    else
      # No available accounts - allow stop, enter SLEEP mode
      echo "Plan limit reached. No available accounts to switch to. All accounts exhausted or in cooldown." >&2

      # Write sleep state for codex-autonomous to detect (session-specific)
      local session_suffix
      session_suffix=$(get_session_suffix)
      local sleep_file="${STATE_DIR}/.account-sleep-mode${session_suffix}"
      mkdir -p "$(dirname "${sleep_file}")"
      if ! ACCOUNT="${current_email}" TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" COOLDOWN="${COOLDOWN_MINUTES}" jq -n \
        '{exhausted_account: env.ACCOUNT, timestamp: env.TS, cooldown_minutes: (env.COOLDOWN | tonumber), reason: "all_accounts_exhausted"}' > "${sleep_file}" 2>/dev/null; then
        echo "Warning: Failed to write sleep state file" >&2
      fi

      # Force Codex to exit so codex-autonomous can handle cooldown
      terminate_codex "all accounts exhausted"

      exit 0
    fi
  fi

  # No plan limit detected - allow normal stop evaluation
  exit 0
}

main "$@"
