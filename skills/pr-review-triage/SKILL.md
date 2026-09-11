---
name: pr-review-triage
description: Triage a PR's review comments — takes a remote PR URL or a path to a saved review file, verifies each comment against the current codebase, and classifies every comment as LEGITIMATE (fix it), IGNORABLE (valid but low-value / nit / accepted tradeoff), or DOES-NOT-APPLY (wrong or already handled). Use when the user says "triage this PR", "which review comments on <PR url> are legit", "/pr-review-triage", or hands you a PR link or a review file to go through.
---

# PR Review Triage

Read a PR's review comments and tell the user which are worth acting on. **Verify every
comment against the actual current code — never trust the reviewer's framing at face value.** A
comment that describes a bug the code doesn't have is `DOES-NOT-APPLY`, no matter how confident it
sounds.

## Inputs

The skill needs **one source of review comments**, given as either:

- **A remote PR link** — e.g. `https://github.com/<owner>/<repo>/pull/123`. Also accept a
  GitLab/Bitbucket merge-request URL.
- **A path to a review file** — a local file (or a link to one) holding the review comments, e.g.
  `./pr-reviews/pr-123.md` or an absolute path.

If the user gave **neither**, **ask for one and stop**:

> Which PR should I triage? Paste the PR link, or the path to the review file.

Do **not** guess, do **not** accept a bare PR number, and do **not** assume a default reviews
directory — a number alone is ambiguous about the repo and the host, so ask for the full link or a
concrete file path.

## Fetching the review

### From a PR link

Use `gh` (GitHub):

```
gh pr view <url> --json title,body,headRefName,baseRefName,url
gh api repos/<owner>/<repo>/pulls/<no>/comments --paginate   # inline review comments
gh api repos/<owner>/<repo>/pulls/<no>/reviews  --paginate   # review summaries
gh pr view <url> --json comments                             # top-level discussion
```

Take the file path, line, and body from each inline comment; those are your per-comment anchors.
Skip bot noise and resolved/outdated threads unless the user asks to include them, and say how many
you skipped. If `gh` isn't installed or isn't authenticated for that host, say so and ask the user
to paste the review as a file instead.

For a non-GitHub URL, use the host's CLI/API if one is available; otherwise ask for a file.

### From a review file

Read the file at the given path. If it doesn't exist, say so and ask for the correct path — don't
go hunting through the filesystem for a similarly named file.

### File format

A saved review file is a flat list of review comments. Each comment begins with a header line:

```
In <repo-relative-file-path>:
```

followed by a diff/code snippet (lines starting with `>`, `+`, `-`, or context), then prose: the
reviewer's concern, and often a "Suggested fix:" line. Comments are separated by the next `In …:`
header. A single header may carry more than one distinct concern in its prose — split those into
separate findings. Reviewers tag severity loosely ("nit:", "Q:") — treat those as hints, not the
verdict; you decide the verdict from the code.

## Procedure

1. **Parse** the source into individual comments. Number them C1, C2, … in file order so the user can
   map back to the source (for a fetched PR, also note the reviewer and comment URL).
2. **For each comment, open the referenced file(s) at the relevant code** and confirm the current
   state. Check whether:
   - the code the comment describes still exists as quoted (the PR may have moved on),
   - the claimed defect is actually reachable (trace callers, locks, transactions, guards),
   - the concern is already handled elsewhere (an existing lock, filter, validation, or a
     fast-follow the team already tracks).
   Use Grep/Read/Glob and the Explore agent for wide checks. Do the work — this is verification, not
   summarization.
3. **Classify** each comment into exactly one bucket (below).
4. **Report** using the output format below. Do NOT fix anything unless the user explicitly asks —
   this skill triages; a follow-up (`/gs:resolve-todos` or a direct request) fixes.

## Classification buckets

- **✅ LEGITIMATE — fix it.** A real defect or gap in the *current* code: wrong behavior, a
  reachable race, an unbounded query, a soft-delete/read-filter miss, a security or validation hole,
  a contract/doc that contradicts the code. Verified present. These are the ones to action.

- **🟡 IGNORABLE — valid but not worth acting on now.** The observation is technically correct but
  low-value or out of scope: pure style/nit with no correctness impact, a deliberate and reasonable
  tradeoff, a performance concern that's real only at scale with no current symptom, or a suggested
  fast-follow the team can defer. Say *why* it's deferrable and note if it's worth a backlog ticket.

- **❌ DOES-NOT-APPLY — wrong or moot.** The comment misreads the code, the described defect isn't
  reachable (a lock/transaction/guard the reviewer missed already prevents it), the code already does
  what's suggested, or the quoted code no longer exists / changed. Cite the specific file:line that
  disproves it.

When genuinely uncertain after checking, say so — put it in the bucket it's closest to and flag the
open question rather than pretending confidence.

## Output format

Start with a one-line count summary, then a section per bucket, most important first. For each
comment:

```
### ✅ LEGITIMATE

**C3 — apps/backend-api/src/lib/budget/containment.ts** (cross-phase race)
Reviewer's point: <one sentence>.
Verdict: Confirmed — <what you checked and found>, e.g. `project-phase-activity.service.ts:47`
only locks the single phase, so two concurrent writes to different phases both pass the check.
Action: <the concrete fix, terse>.
```

Then `🟡 IGNORABLE` and `❌ DOES-NOT-APPLY` sections in the same shape (for those, "Action" becomes
"Why deferrable" / "Why it doesn't apply").

Close with a short **Recommended order of work** listing just the LEGITIMATE comment IDs.

## Rules

- Respect this project's conventions when judging (from CLAUDE.md and `.claude/rules/`): soft-delete +
  read filters, pagination on list endpoints, DDD layering, swagger annotations, mobile error-display
  and SWR fetch rules. A comment enforcing one of these hard-blocks is almost always LEGITIMATE.
- Cite `file:line` for every verdict — the user needs to jump to it.
- Be decisive. A triage that marks everything "legitimate, verify further" is useless. Commit to a
  bucket per comment.
- Read-only by default. No edits, no commits.
