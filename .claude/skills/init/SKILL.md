# /init - Session Bootstrap

Initialize the session with the full programming model. Run this first in every session.

## Workflow

1. **Run gather script** (read-only, no side effects):

   ```bash
   ./scripts/init-gather.sh
   ```

   This produces a JSON object with:
   - `branch` — current git branch
   - `recentCommits` — last 5 commits (hash + message)
   - `inProgressPlan` — first in-progress plan with phase tracking (`null` if none)
   - `plannedPlans` — list of plans with status "planned"
   - `featureFiles` — domain knowledge files in `.claude/features/`
   - `sessionModel` — full content of `.claude/session-model.md`
   - `lastCommitTime` — relative time of last commit
   - `lastCommitMessage` — subject of last commit

2. **Detect work context** from the JSON:

   - If `inProgressPlan` is not null → this is a **plan resumption**
   - If `plannedPlans` is non-empty → surface them as candidates
   - If both are empty → ready for new work

3. **Check permissions**

   Read `.claude/settings.json` and verify that `Bash`, `Write`, and `Edit` are in the `allow` list. If multi-agent orchestration will be needed (plan-based work), warn if permissions may cause agent blocking.

4. **Output session briefing**

   Use the JSON data to display a concise briefing in this exact format:

   ```
   ══════════════════════════════════════════════
    SESSION INITIALIZED
   ══════════════════════════════════════════════

    Branch:  {branch}
    Plan:    {inProgressPlan.title} ({status}, Phase {currentPhase}/{totalPhases}) — or "(none)"
    Domain:  {first matching featureFile} — or "(none loaded)"
    Last:    {lastCommitTime} — "{lastCommitMessage}"

    Model:
     ✓ Strict TDD (red → green → refactor → commit)
     ✓ 4-agent orchestration (orchestrator, implementor, verifier, chronologist)
     ✓ BDD 4-layer (Test → DSL → Protocol Driver → SUT)
     ✓ Guardrails active (18 IF + 18 GR)
     ✓ Commit per green cycle

    {context-specific prompt — see below}
   ══════════════════════════════════════════════
   ```

5. **Context-specific prompt**

   Based on detected context, end the briefing with the appropriate prompt:

   - **Resuming a plan:** `"Resuming {plan title} at Phase {N}. Ready to launch orchestration?"`
     - If the plan has a readiness assessment, include: `"Assessment: {BAND} — {N} preparation tasks pending"` (or `"all preparation complete"`)
     - If the plan's band is ORANGE/RED and `needs_decomposition`: `"Plan {title} needs decomposition (rated {BAND}). Decompose before implementing."`
   - **Planned work available:** `"Found {N} planned feature(s). Which one to start? Or describe new work."`
     - For each listed plan with a readiness assessment, append its band (e.g., `"[YELLOW — 2 prep tasks]"`)
   - **No plans:** `"No active plans. Describe what you'd like to work on — I'll route to the right workflow."`

6. **Route to workflow** (after user responds)

   Based on the user's response:

   - **Bug fix** → Remind: "Strict TDD — I'll write a failing test reproducing the bug first, then fix."
   - **Planned feature** → Run `/implement-feature` with 4-agent orchestration. Update plan status to `in_progress`.
   - **New feature (no plan)** → Ask: "Want me to create a plan first (`/plan`)? Or proceed directly with TDD and track as unplanned?"
   - **Exploration / question** → Answer directly, no orchestration needed.

## Rules

- `/init` is READ-ONLY during the gathering phase — it must not modify any files
- The session briefing must be scannable in under 10 seconds
- The `sessionModel` field contains the full programming model — internalize it, do not display it verbatim
- If the user describes work that matches an existing plan, auto-associate
- For plan-based work, always use 4-agent orchestration (never single-agent sequential)
- Every implementation/verification/chronology cycle ends with a commit
