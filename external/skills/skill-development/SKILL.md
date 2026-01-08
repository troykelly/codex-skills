---
name: skill-development
description: Use when the user wants to create or refine Codex skills, improve skill descriptions, organize skill resources, or follow Codex skill best practices.
---

# Skill Development (Codex)

This skill provides guidance for creating effective Codex skills and aligning with current Codex CLI conventions.

## What Skills Are

Skills are modular packages that give Codex reusable workflows, domain knowledge, and tooling. Codex uses a skill in two ways:

- **Implicit invocation:** Codex selects a skill when the user's request matches its description.
- **Explicit invocation:** The user mentions `$skill-name` (or uses the `/skills` picker in supported clients).

## Where to Save Skills (Codex Scopes)

Codex loads skills from these locations, in precedence order (highest to lowest):

1. `$CWD/.codex/skills`
2. `$CWD/../.codex/skills` (if inside a git repo)
3. `$REPO_ROOT/.codex/skills` (git repo root)
4. `$CODEX_HOME/skills` (default `~/.codex/skills`)
5. `/etc/codex/skills`

Notes:
- Higher-precedence skills override lower-precedence ones with the same name.
- Codex ignores symlinked skill directories.

## Skill Structure

```
skill-name/
├── SKILL.md   (required)
├── scripts/   (optional)
├── references/ (optional)
└── assets/    (optional)
```

## SKILL.md Requirements

`SKILL.md` must include YAML frontmatter with:

- `name`: non-empty, <= 100 characters, single line
- `description`: non-empty, <= 500 characters, single line

Extra keys are ignored by Codex.

Example:

```yaml
---
name: draft-commit-message
description: Draft a conventional commit message when the user asks for help writing a commit message.
---
```

## Creation Workflow

1. **Clarify triggers**
   Define concrete user phrases that should activate the skill. Keep the description specific.

2. **Plan reusable resources**
   Decide which scripts, references, or assets will save time. Prefer scripts for deterministic steps.

3. **Create the skill folder**
   Put it in a valid Codex skill path (see scopes above).

4. **Write SKILL.md**
   Keep it lean. Use imperative instructions and link out to references for detailed material.

5. **Add references or scripts**
   Store long docs in `references/` and reusable code in `scripts/`.

6. **Restart Codex**
   Codex loads skills at startup. Restart to pick up changes.

## Best Practices

- **Be explicit in descriptions** so Codex can trigger correctly.
- **Use progressive disclosure**: keep SKILL.md short and move details into references.
- **Avoid overlapping descriptions** to prevent ambiguous triggers.
- **Validate frontmatter length and single-line fields** to avoid startup validation errors.

## Related Resources

- `references/skill-creator-original.md` for deeper guidance on structure and progressive disclosure
