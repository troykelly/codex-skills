# Hook Development Utility Scripts (Codex)

These scripts help validate, test, and lint hook implementations before use by a Codex hook runner.

Reference runner: `scripts/codex-hook-runner` (installed by `install.sh`) expects `hooks.json` in `$CODEX_HOOK_ROOT` (default: `$CODEX_HOME/hooks`).

## validate-hook-schema.sh

Validates `hooks.json` configuration files for correct structure and common issues.

**Usage:**
```bash
./validate-hook-schema.sh path/to/hooks.json
```

**Checks:**
- Valid JSON syntax
- Required fields present
- Valid hook event names
- Proper hook types (command/prompt)
- Timeout values in valid ranges
- Hardcoded path detection

## test-hook.sh

Tests individual hook scripts with sample input.

**Usage:**
```bash
./test-hook.sh [options] <hook-script> <test-input.json>
```

**Options:**
- `-v, --verbose` - Show detailed execution information
- `-t, --timeout N` - Set timeout in seconds (default: 60)
- `--create-sample <event-type>` - Generate sample test input

**Example:**
```bash
./test-hook.sh --create-sample PreToolUse > test-input.json
./test-hook.sh -v my-hook.sh test-input.json
```

**Features:**
- Sets up environment variables (`CODEX_PROJECT_ROOT`, `CODEX_HOOK_ROOT`)
- Measures execution time
- Validates output JSON
- Shows exit codes and their meanings

## hook-linter.sh

Checks hook scripts for common issues and best practices violations.

**Usage:**
```bash
./hook-linter.sh <hook-script.sh> [hook-script2.sh ...]
```

**Checks:**
- Shebang presence
- `set -euo pipefail` usage
- Stdin input reading
- Proper error handling
- Variable quoting (injection prevention)
- Exit code usage
- Hardcoded paths
- Long-running code detection
- Error output to stderr
- Input validation

## Typical Workflow

1. **Write your hook script**
   ```bash
   vim hooks/my-hook.sh
   ```

2. **Lint the script**
   ```bash
   ./hook-linter.sh hooks/my-hook.sh
   ```

3. **Create test input**
   ```bash
   ./test-hook.sh --create-sample PreToolUse > test-input.json
   ```

4. **Test the hook**
   ```bash
   ./test-hook.sh -v hooks/my-hook.sh test-input.json
   ```

5. **Add to hooks.json**
   ```bash
   # Edit hooks/hooks.json
   ```

6. **Validate configuration**
   ```bash
   ./validate-hook-schema.sh hooks/hooks.json
   ```

## Tips

- Keep hooks fast and deterministic
- Use verbose mode (`-v`) to debug behavior
- Validate `hooks.json` after any changes
- Create multiple test inputs (safe operations, risky operations, edge cases)
