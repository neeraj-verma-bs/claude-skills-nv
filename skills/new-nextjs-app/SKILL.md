---
name: new-nextjs-app
description: Scaffold a new Next.js project with create-next-app in the current or a specified directory, after checking every prerequisite (Node version, package manager, git, registry reachability, target directory) and offering to install anything missing. Also seeds the new project's .claude/ folder with this plugin's skills and commands. Use when the user says "create a nextjs app", "new next project", "scaffold next.js", or "/new-nextjs-app".
---

# New Next.js App

Scaffold a Next.js project, but **verify the machine can actually build it first** and never install
anything without asking. macOS and Linux only — if `uname -s` is anything else, say so and stop.

## Step 1 — Intake

Gather from the user's request:

| Input | Default if unstated |
| --- | --- |
| Project name | **Ask and stop** — don't invent one |
| Target directory | The current working directory |
| TypeScript | yes |
| Tailwind CSS | yes |
| ESLint | yes |
| App Router | yes |
| `src/` directory | yes |
| Turbopack | yes |
| Import alias | `@/*` |
| Package manager | whatever the probe in step 2 detects |

The project name must be a valid npm package name: lowercase, no spaces, no leading dot or
underscore. If the user's name violates that, propose a slugified version and confirm.

"In the current directory" means scaffolding **into** the cwd rather than into a new subfolder —
`create-next-app .`. Distinguish that from "in `~/code`", which means `~/code/<name>`. If the phrasing
is ambiguous, state which one you're doing before running anything.

Don't interrogate the user about every flag. Take the defaults above silently and only ask about
options they hinted at.

## Step 2 — Check prerequisites

Run the probe, passing the resolved target directory:

```
sh "${CLAUDE_PLUGIN_ROOT}/skills/new-nextjs-app/scripts/check-prereqs.sh" <target-dir>
```

It is read-only — it installs nothing and writes nothing. It prints a table plus trailing
`KEY=value` lines: `PLATFORM`, `PACKAGE_MANAGER`, `NODE_INSTALLER`, `WARNINGS`, `BLOCKERS`, and
`RESULT`. Exit code is `0` for READY, `1` for BLOCKED, `2` for an unsupported platform.

What it covers: Node presence and version (>= 20.9.0 for Next 16; set `NEXT_MIN_NODE=18.18.0` if the
user pins Next 15), npm/pnpm/yarn/bun, corepack, git plus `user.name`/`user.email`, npm registry
reachability, target-directory state and writability, and free disk space.

**Show the user the table.** Don't paraphrase it away — they should see what was checked.

## Step 3 — Offer to fix what's missing

The script prints ready-to-run install commands under "Suggested fixes", chosen for the detected
platform and the version manager that's actually present (`fnm`, `volta`, `mise`, `asdf`, `nvm`,
Homebrew, or the distro's `apt-get`/`dnf`/`pacman`/`zypper`).

- **`RESULT=BLOCKED`** — the scaffold cannot proceed. List each blocker with its fix, then **offer to
  run the fixes**: "Want me to run these?" Run them **only on an explicit yes**, one at a time,
  showing output. Then re-run the probe and continue. If they decline, stop — don't try to work
  around a missing Node.
- **Warnings** — report them and continue, except for the two that will visibly bite:
  - unset `git user.name`/`user.email` → offer to set them before scaffolding, since the initial
    commit fails otherwise
  - a non-empty target directory → see step 4
- Anything needing `sudo` (a distro package manager) gets flagged as such **before** you offer to run
  it. Prefer a user-level version manager over `sudo` when the probe found one.

Never run an install command the script didn't suggest, and never install a global npm package to
work around a gap.

## Step 4 — Confirm the target directory

If the probe warned that the directory is non-empty:

1. List what's in it.
2. If it holds a `package.json`, treat that as a likely mistake — say so and ask before continuing.
3. Otherwise ask for explicit confirmation. `create-next-app` refuses to overwrite conflicting files,
   but confirm anyway so the user isn't surprised.

Never delete or move anything to clear the way. If the user wants a clean directory, they do it.

## Step 5 — Scaffold

Build the command from the resolved options, using the runner for the detected package manager:

| Package manager | Runner |
| --- | --- |
| npm | `npx create-next-app@latest` |
| pnpm | `pnpm create next-app@latest` |
| yarn | `yarn create next-app` |
| bun | `bunx create-next-app@latest` |

Pass **every** option as an explicit flag so the command never blocks on an interactive prompt:

```
npx create-next-app@latest <name-or-.> \
  --ts --tailwind --eslint --app --src-dir --turbopack \
  --import-alias "@/*" \
  --use-npm \
  --yes
```

Negate with the `--no-` form (`--no-tailwind`, `--no-eslint`, `--js` for plain JavaScript). Swap
`--use-npm` for `--use-pnpm` / `--use-yarn` / `--use-bun` to match. Quote any path containing spaces.

This downloads a lot — expect it to run for a while, and don't kill it early. If it fails, show the
real error rather than retrying blind; a registry or permissions failure needs the user, not a retry.

## Step 6 — Seed the project's `.claude/`

Copy this plugin's skills and commands into the new project so they're available there immediately:

```
<target>/.claude/skills/<each dir in ${CLAUDE_PLUGIN_ROOT}/skills/>
<target>/.claude/commands/<each file in ${CLAUDE_PLUGIN_ROOT}/commands/>
```

Rules:

- **Enumerate the plugin directories at runtime** — never hardcode a list of skills. New skills added
  to the plugin then get picked up by future scaffolds automatically.
- Copy `agents/` too if it holds anything other than `.gitkeep`.
- If a destination file already exists (possible when scaffolding into a non-empty directory),
  **ask before overwriting**. Default to keeping the existing file.
- These are copies, not links. They're a snapshot and will drift as the plugin changes; to refresh a
  project later, re-run this step. Mention that once, in the final report.

## Step 7 — Verify and report

1. Confirm `package.json`, `node_modules/`, and the app directory exist.
2. Offer to run a production build (`<pm> run build`) to prove the toolchain works — **ask first**,
   it's slow. Don't start the dev server; it doesn't exit.
3. Report:
   - absolute path of the project
   - options actually used
   - anything you installed or changed **on the user's machine** (call this out explicitly)
   - skills/commands copied into `.claude/`
   - the commands to run it: `cd <path> && <pm> run dev`

## Rules

- **Ask before installing anything**, on the machine or globally. The probe never installs; step 3
  only proposes.
- **Never delete or overwrite** user files to make room. Ask, or stop.
- **Show the probe's table** rather than summarizing it away.
- **Non-interactive flags only** — an interactive `create-next-app` prompt will hang the session.
- **macOS and Linux only.** On anything else, stop and say so.
- Report failures with the actual error output. Don't retry a failed install more than once.
