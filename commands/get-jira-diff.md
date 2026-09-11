---
name: gs:get-jira-diff
description: 'Utility: Fetch Jira tickets and diff each against the current codebase — surface what is implemented, partial, or missing'
argument-hint: '[Jira ticket links or keys/text — e.g. GSSP-47 GSSP-52, or paste ticket URLs]'
model: opus
---

# /gs:get-jira-diff

> **TASK TRACKING:** Before starting, create a task for each numbered step below. Mark each complete as you go.

Fetch one or more Jira tickets and diff each ticket's requirements against the **current implementation in the codebase** — identifying what is fully implemented, partially implemented, or missing entirely.

This is a **ticket-vs-code gap analysis**, not a ticket-vs-ticket comparison. Every ticket passed as an argument is checked against the actual code.

## Step 1: Intake

Parse `$ARGUMENTS` for Jira references. Accept any of:

- Issue keys (e.g. `GSSP-47`, `GSSP-52`)
- Full Jira URLs (e.g. `https://<site>.atlassian.net/browse/GSSP-47`)
- Free text describing the tickets

**If no tickets are provided, STOP and ask the user:** "Which Jira ticket(s) should I diff against the code? Paste the ticket links or keys."

One ticket is enough — each ticket is analyzed independently against the codebase.

## Step 2: Fetch Tickets

Use the Atlassian MCP tools (load schemas via ToolSearch first if needed):

1. `getAccessibleAtlassianResources` — resolve the `cloudId` for the site.
2. For each reference: `getJiraIssue` (by key) — pull summary, description, acceptance criteria, status, issue type, components, labels, linked issues, and subtasks.
3. If a reference is text-only, use `searchJiraIssuesUsingJql` to locate the matching issue, then fetch it.

If a ticket cannot be fetched (permission, wrong key, wrong site), report which one and continue with the rest.

## Step 3: Extract Requirements (the contract)

For each ticket, distill the implementation-relevant facts the code must satisfy:

- **Goal / summary** — what is being built
- **Acceptance criteria** — the contract, broken into discrete, checkable tasks
- **Scope** — apps/libs expected to be touched (backend-api, frontend-web, mobile, shared-types, shared-utils)
- **Data model / API surface** — endpoints, types, schema changes the ticket calls for
- **Dependencies / linked tickets** — blockers and relations

Decompose each ticket into an explicit checklist of concrete, verifiable tasks. This checklist is what you diff against the code.

## Step 4: Locate & Inspect the Implementation

For each ticket, find the actual code that implements (or should implement) its requirements:

1. Map the ticket's scope to the relevant apps/libs and domains.
2. Search the codebase for the routes, controllers, services, repositories, schemas, types, components, and tests that correspond to each acceptance-criteria task. Use Grep/Glob and dispatch `Explore` agents for broad sweeps.
3. Inspect what exists: does the endpoint/type/component/migration exist? Does it match the ticket's data model and acceptance criteria? Are the required tests present?
4. Cover the whole stack the ticket implies — backend (route → controller → service → repository → schema → migration), frontend/mobile, shared-types, and tests.

**Evidence-based only** — cite `file_path:line` for every "implemented" or "partial" claim. If you cannot find code for a task, it is a gap, not an assumption.

## Step 5: Diff Requirements vs Code

For each ticket, classify every acceptance-criteria task:

- ✅ **Implemented** — code exists and matches the ticket's intent (with file evidence).
- ⚠️ **Partial / Drifted** — code exists but is incomplete, diverges from the acceptance criteria, missing tests, or missing error/edge handling.
- ❌ **Missing** — no code found for this requirement.

Also flag:

- **Drift** — code that contradicts the ticket's data model, API shape, or acceptance criteria.
- **Out-of-scope code** — implementation present that the ticket does not call for (possible scope creep or untracked work).
- **Sequencing** — gaps blocked by unimplemented dependencies / linked tickets.

## Step 6: Report

Output a per-ticket gap analysis:

```
## Tickets Analyzed
- GSSP-47 — <summary> (<status>)
- GSSP-52 — <summary> (<status>)

## GSSP-47 — <summary>
**Coverage:** X of Y acceptance criteria implemented

| Task (from ticket)          | Status      | Evidence / Gap                         |
| --------------------------- | ----------- | -------------------------------------- |
| <acceptance criterion 1>    | ✅          | `apps/backend-api/.../foo.ts:42`       |
| <acceptance criterion 2>    | ⚠️ Partial  | exists but missing tests / diverges    |
| <acceptance criterion 3>    | ❌ Missing  | no implementation found                |

**Drift & Out-of-scope:**
- ...

**What's needed to close the gap:**
1. ...

## GSSP-52 — <summary>
(same structure)

## Summary Across Tickets
- Highest-risk gaps: ...
- Recommended sequencing: ...
```

## Key Rules

- **Ticket-vs-code, not ticket-vs-ticket** — every ticket is diffed against the actual implementation. When multiple tickets are passed, analyze each independently, then summarize across them.
- **One ticket is valid** — no minimum; each is analyzed on its own.
- **Fetch, don't assume** — always pull live ticket data; never infer ticket content from the key alone.
- **Evidence or it's a gap** — cite `file_path:line` for every implemented/partial claim. Missing evidence means missing implementation.
- **Decompose first** — break acceptance criteria into discrete checkable tasks before searching the code.
- **Fix at the source** — if the code contradicts the ticket (or the ticket contradicts itself), surface it; don't paper over it.
- **Degrade gracefully** — if one ticket fails to fetch, report it and analyze the rest.
