# Codex Skill Creation Notes

This reference summarizes Codex skill creation guidance and validation rules.

## How Codex Loads Skills

- Codex always loads **name**, **description**, and **file path** for each skill.
- The SKILL.md body and extra resources are only loaded when the skill is invoked.

## Frontmatter Rules

- `name`: non-empty, <= 100 characters, single line
- `description`: non-empty, <= 500 characters, single line
- Extra keys are ignored

## Skill Locations (Precedence)

1. `$CWD/.codex/skills`
2. `$CWD/../.codex/skills` (repo parent)
3. `$REPO_ROOT/.codex/skills`
4. `$CODEX_HOME/skills` (default `~/.codex/skills`)
5. `/etc/codex/skills`

Higher precedence overrides lower precedence if names collide.

## Suggested Creation Flow

1. Use `$skill-creator` to bootstrap (preferred).
2. Keep SKILL.md concise.
3. Put large references under `references/`.
4. Put deterministic code under `scripts/`.
5. Restart Codex after changes.

## Common Validation Failures

- Multi-line `name` or `description`
- Over-length `name` or `description`
- Missing required fields
- Symlinked skill directories
