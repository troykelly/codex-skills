# Migrating from Script-Only Gates to Prompt Hooks (Codex)

This guide shows how to migrate from basic command hooks to prompt-based hooks for better maintainability and flexibility.

## Why Migrate?

Prompt hooks offer:

- Context-aware decisions
- Better edge case handling
- Easier updates (no bash changes)
- Clear natural-language explanations

## Migration Example: Bash Command Validation

### Before (Command Hook)

**hooks.json:**
```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {"type": "command", "command": "bash validate-bash.sh"}
      ]
    }
  ]
}
```

**validate-bash.sh:**
```bash
#!/bin/bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

if [[ "$command" == *"rm -rf"* ]]; then
  echo "Dangerous command detected" >&2
  exit 2
fi
```

### After (Prompt Hook)

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Command: $TOOL_INPUT.command. Check for destructive operations, privilege escalation, or unexpected network access. Return approve|deny with reason."
        }
      ]
    }
  ]
}
```

## Migration Example: File Write Validation

### Before (Command Hook)

```json
{
  "PreToolUse": [
    {
      "matcher": "Write",
      "hooks": [
        {"type": "command", "command": "bash validate-write.sh"}
      ]
    }
  ]
}
```

### After (Prompt Hook)

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "File path: $TOOL_INPUT.file_path. Validate against system dirs, secrets, traversal. Return approve|deny with reason."
        }
      ]
    }
  ]
}
```

## When to Keep Command Hooks

Command hooks are still ideal when:

- Validation is deterministic and fast
- You need to call a CLI tool
- You want to keep strict, testable logic

Use a prompt hook for subjective or contextual checks.
