---
name: hook-development
description: Use when the user wants to create Codex workflow hooks (pre/post run gates, tool-use validators, stop checks) or needs guidance on hook scripts and hooks.json configuration.
---

# Hook Development (Codex)

## Overview

Codex CLI does not provide Claude-style hook events. To replicate hook behavior, implement a **hook runner** (wrapper script or CI job) that:

1. Runs hook scripts before/after `codex exec`.
2. Optionally parses `codex exec --json` output to detect tool usage.
3. Applies a `hooks.json` configuration to decide which hooks to run.

This skill defines a **Codex hook contract** and provides utilities for validating, testing, and linting hooks.

This repository ships a reference runner at `scripts/codex-hook-runner` (installed by `install.sh`) that implements the contract described below. Hooks are enabled by default in `codex-autonomous`; set `CODEX_DISABLE_HOOKS=1` to disable.

## Hook Types

### Prompt Hooks (LLM-driven)
Use an LLM (Codex or another model) to make contextual decisions.

```json
{
  "type": "prompt",
  "prompt": "Validate this operation. Return approve|deny with a reason."
}
```

### Command Hooks (Deterministic)
Use shell scripts for fast, repeatable checks.

```json
{
  "type": "command",
  "command": "bash ${CODEX_HOOK_ROOT}/scripts/validate-write.sh",
  "timeout": 30
}
```

## Hook Configuration (hooks.json)

Define hooks in a single `hooks.json`. This format is consumed by your hook runner.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CODEX_HOOK_ROOT}/scripts/validate-write.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Review transcript at $TRANSCRIPT_PATH. Block if tests were not run after code changes."
          }
        ]
      }
    ]
  }
}
```

If your runner prefers a direct format, you can omit the `hooks` wrapper and use events at top level. `scripts/validate-hook-schema.sh` supports both.

## Hook Events (Codex Mapping)

Your hook runner chooses which events to emit. Recommended events:

- `SessionStart`: before running Codex
- `UserPromptSubmit`: after prompt is assembled but before execution
- `PreToolUse`: before a tool call (requires `--json` parsing)
- `PostToolUse`: after a tool call (requires `--json` parsing)
- `Stop`: before accepting the final response
- `SessionEnd`: after the run completes
- `SubagentStop`: for worker processes spawned by `worker-dispatch`

## Hook Script Contract

Hook scripts receive JSON on stdin and return decisions via exit code:

- Exit 0: allow / continue
- Exit 2: block (stderr message is surfaced)

Recommended output shape for decision hooks:

```json
{
  "decision": "allow|deny|ask",
  "reason": "short explanation",
  "systemMessage": "optional context for the main agent"
}
```

### Input Fields (Suggested)

```
{
  "event": "PreToolUse",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {"file_path": "..."},
  "tool_result": {"stdout": "..."},
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write"
}
```

Your runner may add additional fields as needed.

## Environment Variables

The hook runner should set:

- `CODEX_PROJECT_ROOT`: repository root
- `CODEX_HOOK_ROOT`: directory containing `hooks.json` and scripts
- `CODEX_ENV_FILE`: path to a file for exporting environment variables (optional)

## Utilities

Use these helper scripts while developing hooks:

- `scripts/validate-hook-schema.sh`: validate `hooks.json` structure
- `scripts/hook-linter.sh`: lint hook scripts
- `scripts/test-hook.sh`: run hooks with sample inputs

## References

- `references/patterns.md` for common hook patterns
- `references/advanced.md` for advanced techniques
- `references/migration.md` for migrating from script-only gates to prompt-based hooks
- `examples/` for sample hooks
