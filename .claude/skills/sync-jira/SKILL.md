# /sync-jira - JIRA Plan Synchronization

Detect drift between local plan files and JIRA tickets using snapshot-based three-way merge. Auto-resolve safe drifts, prompt for conflicts.

> **Script:** `./scripts/jira-sync.sh` — invoke directly for zero-token execution.

## Prerequisites

- JIRA MCP server configured (`mcp-jira-cloud` or equivalent)
- `~/.claude/scripts/jira-update-description.sh` for ADF-formatted description updates (the MCP tool's description field only supports plain text)

## Arguments

- `[plan-id|all]`: A plan ID (e.g., `PROJ-1`) or `all` to sync every plan in the index. Defaults to the current in-progress plan if omitted.

## Workflow

### 1. Resolve Target Plans

If argument is `all`, read `plans/index.json` and collect all plan IDs. If a specific ID, validate it exists in the index. If no argument, find the first plan with `"status": "in_progress"`. Error if no in-progress plan and no argument given.

### 2. Identify Interacting User

On the first sync invocation, resolve the current JIRA user:

```
mcp__jira__jira_whoami()
```

Extract the `accountId`. Cache it for the duration of the sync run. This is used in step 6 to default-assign unassigned issues.

### 3. For Each Plan: Gather Three States

#### a. Load snapshot (baseline)

Read `plans/.sync/<plan-id>.json`. If the file does not exist, this is a **first sync** — skip conflict detection and proceed directly to step 7 (capture initial snapshot).

#### b. Read JIRA current state (remote)

Fetch the epic:

```
mcp__jira__jira_get_issue({ issueKey: "<plan-id>" })
```

Fetch child stories:

```
mcp__jira__jira_search_issues_summary({ jql: "parent = <plan-id>" })
```

Extract per story: `key`, `status`, `summary`.
Extract per epic: `key`, `status`.

**Status normalization:** JIRA may return localized status names (e.g., German: `Zu erledigen`, `In Arbeit`, `Fertig`). Normalize to English (`To Do`, `In Progress`, `Done`) before comparison. On first run, use `mcp__jira__jira_get_transitions` to discover the status names and transition IDs for the project.

#### c. Parse plan file current state (local)

Use the plan parser script to extract structured data:

```bash
./scripts/parse-plan-markdown.sh "plans/<plan-id>.md"
```

This returns JSON with: `title`, `goal`, `stories` (phase, label, jiraKey, checked), `assessment` (composite, band, dimensions), `jiraEpicKey`.

Additionally read `plans/index.json` for the epic's plan status.

### 4. Compute Diff Classification

Flatten each state (snapshot, local, remote) into a flat JSON object with dot-separated keys (e.g., `stories.PROJ-5.status`, `epic.status`, `assessment.compositeScore`), then run the three-way merge script:

```bash
./scripts/three-way-merge.sh <snapshot.json> <local.json> <remote.json>
```

This returns JSON with per-field classifications (IN_SYNC, DRIFTED_LOCAL, DRIFTED_REMOTE, CONFLICT) and actions (none, push, log, push_and_log), plus a summary with counts.

Field groups to flatten:

- `stories.<key>.status` — each story's workflow status
- `stories.<key>.summary` — each story's title
- `epic.status` — epic workflow status
- `assessment.compositeScore` — assessment score (local-only, always plan wins)
- `assessment.band` — assessment band (local-only, always plan wins)

Phase checkboxes are **derived** from story status — never compared independently.

### 5. Resolve: Repository Is the Single Source of Truth

The git repository always represents the truth. JIRA is a **projection** of the repo, not a peer. Sync is **unidirectional push** from plan to JIRA, with JIRA drift surfaced as follow-up artifacts.

#### DRIFTED_LOCAL (plan changed, JIRA didn't)

**Auto-push** plan state to JIRA:

- Story status changed → transition JIRA story via `mcp__jira__jira_transition_issue`
- Story summary changed → update via `mcp__jira__jira_update_issue`
- Epic status changed → transition JIRA epic
- Assessment changed → push description via `~/.claude/scripts/jira-update-description.sh`

#### DRIFTED_REMOTE (JIRA changed, plan didn't)

A human made a decision in JIRA outside the repo. This is **not auto-applied** to the plan. Instead:

1. **Surface the drift** in the sync report with full context (who changed, what changed, when)
2. **Append a `## JIRA Drift Log` entry** to the plan file:

```markdown
### Drift: PROJ-6 status changed in JIRA (YYYY-MM-DD)
- Snapshot: To Do
- JIRA now: In Progress
- Action needed: Review and update plan if appropriate, then re-run /sync-jira
```

3. **Do NOT modify JIRA** — the current JIRA state stands until the plan catches up
4. The drift log entry is the follow-up artifact — it stays until the plan is updated to reflect the decision (or reject it), at which point the next sync pushes the plan's state to JIRA

#### CONFLICT (both changed differently)

Same as DRIFTED_REMOTE — the plan's change is pushed to JIRA (repo wins), and the JIRA-side change is logged as a drift entry for review:

```markdown
### Drift: PROJ-6 status diverged (YYYY-MM-DD)
- Snapshot: To Do
- Plan now: Done (will be pushed to JIRA)
- JIRA was: In Progress (overridden — logged for awareness)
```

The plan value is pushed to JIRA immediately. The log entry documents that a JIRA-side change was overridden.

**Status mapping:**

| Plan checkbox | Plan inline text | JIRA status |
|---|---|---|
| `[ ]` | `To Do` | To Do |
| `[ ]` | `In Progress` | In Progress |
| `[x]` | `Done` | Done |

Before transitioning, call `mcp__jira__jira_get_transitions` to discover available transitions and their IDs for the target project. Transition IDs vary by project and workflow.

### 6. Apply Resolutions

**Push plan → JIRA** (for DRIFTED_LOCAL and CONFLICT):

- Transition story/epic via `mcp__jira__jira_transition_issue`
- Update summary via `mcp__jira__jira_update_issue`
- **ALWAYS rebuild and push the epic description** whenever ANY story status was pushed. Generate ADF using the pipeline:

  ```bash
  ./scripts/parse-plan-markdown.sh "plans/<plan-id>.md" | ./scripts/build-adf-description.sh > /tmp/adf.json
  ```

  Then push via `~/.claude/scripts/jira-update-description.sh`. The ADF must reflect the current state of ALL stories (not just the changed ones). This is non-negotiable — the description is a full projection of the plan, not an incremental update.

**Epic description ADF format** (produced by `build-adf-description.sh`) includes:

1. Context paragraph + dependencies
2. Stories table (ticket, summary, status as ADF `status` lozenge)
3. Assessment heading with composite score + colored emoji circle for band
4. Visual bar chart in an ADF `codeBlock` (language: `text`) using `■□` characters, `⚠` on dimensions ≥ 4
5. Patterns and IO as bold-label paragraphs
6. Verdict paragraph
7. **Implementation Log** (if phases have been completed) — heading + one sub-section per completed phase:
   - Phase name with `status` lozenge (`COMPLETE` = green, `IN PROGRESS` = blue)
   - Completed date
   - Files created/modified in an ADF `codeBlock`
   - Tests count, key decisions, verification result as paragraphs

**ADF visual conventions:**

Status lozenges (`status` node) for story/epic status:

| Status | ADF color |
|---|---|
| Done | `green` |
| In Progress | `blue` |
| To Do | `neutral` |

Colored emoji circles (`emoji` node) for readiness band:

| Band | Emoji shortName |
|---|---|
| GREEN | `:green_circle:` |
| BLUE | `:blue_circle:` |
| YELLOW | `:yellow_circle:` |
| ORANGE | `:orange_circle:` |
| RED | `:red_circle:` |

Example ADF for composite score line:
```json
[
  {"type": "text", "text": "Composite: 1.9 / 5.0 — "},
  {"type": "emoji", "attrs": {"shortName": ":blue_circle:"}},
  {"type": "text", "text": " BLUE (Manageable)", "marks": [{"type": "strong"}]}
]
```

See `/assess-readiness` step 10 for the bar chart rendering rules.

**Default assignment** (for any issue touched during sync):

After pushing status or summary changes to a story or epic, check if the issue has an assignee. If the issue is **unassigned** (no current assignee in JIRA), assign it to the interacting user (accountId from step 2):

```
mcp__jira__jira_assign_issue({ issueKey: "<issue-key>", accountId: "<user-account-id>" })
```

This applies to:
- Stories whose status or summary was pushed (DRIFTED_LOCAL or CONFLICT)
- The epic itself if its status was pushed
- Newly created stories (if the plan contains stories not yet in JIRA)

Issues that already have an assignee in JIRA are left unchanged — this is a **default**, not an override.

**Append drift log** (for DRIFTED_REMOTE and CONFLICT):

- Append entries to `## JIRA Drift Log` section in the plan file (create section if absent)
- Each entry includes: date, field, snapshot value, JIRA value, action needed

### 7. Write New Snapshot

After all resolutions applied successfully, write the converged state to `plans/.sync/<plan-id>.json`.

### 8. Output Sync Report

```
══════════════════════════════════════════════
 SYNC: <plan-id> — <title>
══════════════════════════════════════════════

 Stories:
  PROJ-5  Story summary one               IN_SYNC       Done
  PROJ-6  Story summary two               DRIFTED       To Do → In Progress (pushed)
  PROJ-7  Story summary three             IN_SYNC       Done

 Epic: IN_SYNC (In Progress)
 Assessment: IN_SYNC (1.5 GREEN)

 Result: 1 pushed, 0 JIRA drifts logged
 Snapshot: plans/.sync/<plan-id>.json updated
══════════════════════════════════════════════
```

For first sync (no prior snapshot):

```
══════════════════════════════════════════════
 SYNC: <plan-id> — <title> (initial)
══════════════════════════════════════════════

 Captured initial snapshot from JIRA + plan.
 Stories: 5 | Epic: In Progress | Assessment: 1.5 GREEN
 Snapshot: plans/.sync/<plan-id>.json created
══════════════════════════════════════════════
```

## Snapshot Schema

File: `plans/.sync/<plan-id>.json`

```json
{
  "version": 1,
  "planId": "PROJ-1",
  "capturedAt": "2026-03-30T14:30:00Z",
  "epic": {
    "key": "PROJ-1",
    "status": "In Progress"
  },
  "stories": {
    "PROJ-5": { "status": "Done", "summary": "Story summary one" },
    "PROJ-6": { "status": "To Do", "summary": "Story summary two" }
  },
  "phases": {
    "1": { "checked": true, "storyKey": "PROJ-5", "label": "Phase one label" },
    "2": { "checked": false, "storyKey": "PROJ-6", "label": "Phase two label" }
  },
  "assessment": {
    "compositeScore": 1.5,
    "band": "GREEN"
  }
}
```

## Rules

### Source of Truth

- **Repository is the single source of truth** — Plan files in git are authoritative. JIRA is a projection of the repo, not a peer. Sync is unidirectional: plan → JIRA.
- **JIRA drift is a follow-up, not an override** — When JIRA changes without a corresponding plan change, the drift is logged as a follow-up artifact in the plan file. It is never auto-applied to the plan.
- **Conflicts are won by the plan** — If both plan and JIRA changed, the plan value is pushed to JIRA. The overridden JIRA change is logged for awareness.

### Sync Mechanics

- **Snapshot required for drift detection** — Without a snapshot, the first sync captures baseline only. No changes are pushed on first sync.
- **Never push on first sync** — Initial snapshot captures current state of both sides without modifications.
- **Phase checkboxes are derived** — A checkbox reflects its linked story's status. Phase sync is derived from story status, never independent.
- **Snapshot written last** — Only after all pushes and drift log entries have been successfully applied.
- **`plans/.sync/` is version-controlled** — Snapshots committed to git so collaborators share the baseline.

### JIRA Integration

- **Transition validation** — Before transitioning JIRA, verify target status is reachable via `mcp__jira__jira_get_transitions`. Warn and skip if not.
- **Non-standard JIRA statuses** — If JIRA has a status not in the To Do / In Progress / Done mapping, warn and ask user to classify.
- **JIRA descriptions use ADF** — Rich description updates use `~/.claude/scripts/jira-update-description.sh` with ADF JSON, not the MCP tool's plain text description field.
- **Ampersands in summaries** — Use "and" instead of "&" in JIRA summaries to avoid HTML entity encoding (`&amp;`).

### Default Assignment

- **Unassigned issues get the interacting user** — When sync pushes changes to a JIRA issue that has no assignee, it assigns the issue to the user running `/sync-jira` (resolved via `mcp__jira__jira_whoami` in step 2).
- **Existing assignments are never overridden** — If a JIRA issue already has an assignee, sync does not change it, regardless of who runs the sync.
- **Assignment is a side effect of sync, not a drift field** — Assignee changes are not tracked in the snapshot or drift log. They are a convenience default, not a source-of-truth concern.

### Drift Log Lifecycle

- **Drift entries persist until resolved** — A drift log entry stays in the plan until the plan is explicitly updated (accepting or rejecting the JIRA-side change).
- **Resolved drifts are removed** — When a plan update addresses the logged drift, remove the entry. The next `/sync-jira` run pushes the plan's decision to JIRA.
- **Drift log is committed with the plan** — Drift entries are part of the plan file and go through the normal git workflow.
