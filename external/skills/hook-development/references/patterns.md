# Common Hook Patterns (Codex)

Use these patterns as starting points for Codex workflow hooks. Your hook runner is responsible for emitting events and executing the hooks.

## Pattern 1: Security Validation

Block dangerous file writes using prompt hooks:

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "File path: $TOOL_INPUT.file_path. Verify: not system dirs, not secrets, no traversal. Return approve|deny."
        }
      ]
    }
  ]
}
```

## Pattern 2: Test Enforcement

Ensure tests run before stopping:

```json
{
  "Stop": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Check transcript at $TRANSCRIPT_PATH. If code changed, verify tests ran. Block if missing."
        }
      ]
    }
  ]
}
```

## Pattern 3: Context Loading

Load project context at session start:

```json
{
  "SessionStart": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CODEX_HOOK_ROOT}/scripts/load-context.sh"
        }
      ]
    }
  ]
}
```

**Example script:**
```bash
#!/bin/bash
cd "$CODEX_PROJECT_ROOT" || exit 1

if [ -f "package.json" ]; then
  echo "export PROJECT_TYPE=nodejs" >> "$CODEX_ENV_FILE"
fi
```

## Pattern 4: MCP Tool Monitoring

Protect against destructive MCP operations:

```json
{
  "PreToolUse": [
    {
      "matcher": "mcp__.*__delete.*",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Deletion operation detected. Validate intent and recoverability. Return approve only if safe."
        }
      ]
    }
  ]
}
```

## Pattern 5: Code Quality Checks

Run linters on file edits:

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CODEX_HOOK_ROOT}/scripts/check-quality.sh"
        }
      ]
    }
  ]
}
```
