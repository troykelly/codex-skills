# Advanced Hook Use Cases (Codex)

Advanced patterns for Codex hook runners and scripts.

## Multi-Stage Validation

Combine command and prompt hooks for layered validation:

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CODEX_HOOK_ROOT}/scripts/quick-check.sh",
          "timeout": 5
        },
        {
          "type": "prompt",
          "prompt": "Deep analysis of bash command: $TOOL_INPUT.command",
          "timeout": 15
        }
      ]
    }
  ]
}
```

## Conditional Hook Execution

Skip hooks outside CI:

```bash
#!/bin/bash
if [ -z "$CI" ]; then
  exit 0
fi
```

## Hook Chaining via State

Share state between hooks using temporary files:

```bash
#!/bin/bash
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command')

risk_level=$(calculate_risk "$command")
echo "$risk_level" > /tmp/codex-hook-state-$$
exit 0
```

## Dynamic Hook Configuration

Read project-specific config:

```bash
#!/bin/bash
cd "$CODEX_PROJECT_ROOT" || exit 1

if [ -f ".codex-hooks.json" ]; then
  strict_mode=$(jq -r '.strict_mode' .codex-hooks.json)
  if [ "$strict_mode" = "true" ]; then
    # Apply strict validation
    :
  fi
fi
```

## Context-Aware Stop Gates

Use transcript context:

```json
{
  "Stop": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Review transcript at $TRANSCRIPT_PATH. Confirm tests ran after code changes. Return approve only if complete."
        }
      ]
    }
  ]
}
```

## Performance Optimization

Cache validation results:

```bash
#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path')
cache_key=$(echo -n "$file_path" | md5sum | cut -d' ' -f1)
cache_file="/tmp/codex-hook-cache-$cache_key"

if [ -f "$cache_file" ]; then
  cat "$cache_file"
  exit 0
fi

echo '{"decision": "allow"}' > "$cache_file"
cat "$cache_file"
```
