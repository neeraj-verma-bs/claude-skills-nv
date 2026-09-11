# claude-skills-nv

A personal Claude Code plugin bundling skills, slash commands, hooks and agents.

## Install

From a local checkout:

```
/plugin marketplace add /Users/bigstep/Documents/Neeraj/raw/claude-skills
/plugin install claude-skills-nv@claude-skills-nv-marketplace
```

Once pushed to GitHub, the first line becomes `/plugin marketplace add <owner>/<repo>`.

Verify with `/plugin` (shows installed plugins) and `/help` (lists the commands).

## Contents

### Skills (`skills/`)

| Skill | What it does |
| --- | --- |
| `pr-review-triage` | Takes a PR link or a review file path, verifies each comment against the current code, and buckets them into LEGITIMATE / IGNORABLE / DOES-NOT-APPLY. |
| `new-nextjs-app` | Scaffolds a Next.js project with `create-next-app` after checking prerequisites (macOS/Linux), offering to install what's missing, and copying this plugin's skills into the new project's `.claude/`. |

### Commands (`commands/`)

| Command | What it does |
| --- | --- |
| `/get-jira-diff` | Fetches Jira tickets and diffs each ticket's acceptance criteria against the current codebase. |

### Hooks (`hooks/hooks.json`)

None yet — placeholder.

### Agents (`agents/`)

None yet.

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # lets this repo be added as a marketplace
skills/<name>/SKILL.md
commands/<name>.md
hooks/hooks.json
agents/<name>.md
```

## Adding to the plugin

- **Skill** — `skills/<kebab-name>/SKILL.md` with frontmatter `name` + `description`. The
  description is what Claude matches on, so state the trigger phrases in it.
- **Command** — `commands/<name>.md`. Filename is the command name; frontmatter supports
  `description`, `argument-hint`, `model`, `allowed-tools`. Use `$ARGUMENTS` in the body.
- **Hook** — add an entry to `hooks/hooks.json`; reference scripts with `${CLAUDE_PLUGIN_ROOT}`.
- **Agent** — `agents/<name>.md` with frontmatter `name`, `description`, `tools`.

Skills may ship helper scripts under `skills/<name>/scripts/`; reference them with
`${CLAUDE_PLUGIN_ROOT}`.

Bump `version` in `.claude-plugin/plugin.json` on each change.
