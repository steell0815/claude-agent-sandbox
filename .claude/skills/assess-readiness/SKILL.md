# /assess-readiness - Implementation Readiness Assessment

Score implementation complexity across 8 dimensions, compute a geometric mean composite, and prescribe concrete readiness actions before coding begins.

> **Script:** `./scripts/assessment-publish.sh` — invoke directly for zero-token execution.

## Arguments

- `<plan-id-or-path>`: Plan ID from index or file path to a plan document

## Workflow

1. **Locate the plan**

   ```bash
   ./scripts/plan-index.sh find "<plan-id-or-path>"
   ```

   If the argument is a file path, read it directly. If it's an ID or name, use `plan-index.sh find` to resolve the path.

2. **Read project context**

   Read the plan file, then gather supporting context:

   - `.claude/guardrails.md` — for security and quality constraints
   - `.claude/features/<domain>.md` — for domain complexity
   - Relevant `.claude/*-layer.md` files — for architectural patterns
   - `docs/adr/` — for architectural decisions that affect implementation

3. **Score each dimension**

   Evaluate the plan against the 8-dimension rubric below. Each dimension is scored 1–5 (lower = less complex). When uncertain, score conservatively (higher).

   ### Scoring Rubric

   | # | Dimension | 1 (Trivial) | 2 (Low) | 3 (Moderate) | 4 (High) | 5 (Extreme) |
   |---|-----------|-------------|---------|--------------|----------|-------------|
   | 1 | **Cognitive Complexity** | Single entity, no state transitions | 2-3 entities, simple state | Multiple entities, state machine | Multiple bounded contexts, complex state | Distributed state, saga/choreography |
   | 2 | **BDD Verification Coverage** | All scenarios written as structured GWT | Most scenarios written, minor gaps | Some scenarios, needs expansion | Few scenarios, significant gaps | No scenarios, requirements unclear |
   | 3 | **Dependencies (Coupling)** | Single module, no cross-boundary | 2-3 modules, same bounded context | Cross-context changes needed | Multiple bounded contexts + shared kernel | System-wide cross-cutting concern |
   | 4 | **Business Impact** | No data mutation, display only | Data mutation, easily reversible | Financial/PII data, audited | Regulatory compliance, SLA-bound | Multi-system financial, legal liability |
   | 5 | **Security Surface** | No auth changes, no PII | Minor auth scope changes | New trust boundary or PII field | New auth mechanism, PII processing | Cross-system auth, encryption at rest |
   | 6 | **Pattern Density** | Standard CRUD | 1 pattern (e.g., repository) | 2-3 patterns | 4-5 patterns (e.g., CQRS + events + saga) | 6+ patterns, novel combinations |
   | 7 | **Performance Sensitivity** | No constraints | Soft latency target | Hard latency SLA | High-throughput + latency SLA | Real-time, sub-ms, or burst-scale |
   | 8 | **IO Boundary Breadth** | Pure domain logic, no IO | Single datastore | 2-3 IO boundaries | 4-5 IO boundaries (DB, cache, queue, API) | 6+ IO boundaries, unreliable networks |

4. **Compute geometric mean composite**

   Use the scoring script to compute the composite and band in one step:

   ```bash
   ./scripts/calculate-readiness-composite.sh <d1> <d2> <d3> <d4> <d5> <d6> <d7> <d8>
   # Output: {"composite": 1.86, "band": "BLUE", "label": "Manageable"}
   ```

   Formula: `composite = (d1 × d2 × d3 × d4 × d5 × d6 × d7 × d8) ^ (1/8)`

   The geometric mean stays in the 1–5 range and penalizes any single high dimension.

5. **Map to readiness band**

   The composite script returns the band automatically. To convert a composite float independently:

   ```bash
   ./scripts/get-readiness-band.sh <composite>
   # Output: {"band": "BLUE", "label": "Manageable"}
   ```

   | Range | Band | Label |
   |-------|------|-------|
   | 1.0–1.7 | **GREEN** | Straightforward |
   | 1.8–2.5 | **BLUE** | Manageable |
   | 2.6–3.5 | **YELLOW** | Complex |
   | 3.6–4.5 | **ORANGE** | High complexity |
   | 4.6–5.0 | **RED** | Extreme |

6. **Determine required preparation actions**

   For each dimension scoring ≥ 4, prescribe the corresponding preparation:

   | Dimension | Score ≥ 4 Action |
   |-----------|-----------------|
   | Cognitive Complexity | Create sequence/state diagram before coding |
   | BDD Verification | Write all BDD scenarios as prerequisite; get reviewed |
   | Dependencies | Create dependency map; identify integration test strategy |
   | Business Impact | Define rollback plan; implement feature flag |
   | Security Surface | Create threat model; run `/check-guardrails` proactively |
   | Pattern Density | Find reference implementation in codebase; create ADR if pattern is new |
   | Performance Sensitivity | Define SLAs; add performance acceptance tests |
   | IO Boundary Breadth | Map IO to ports; ensure each has a test double strategy |

7. **Generate decomposition recommendation**

   If band is YELLOW or higher, suggest how to decompose the feature into smaller sub-features that each score lower. For ORANGE/RED, decomposition is **mandatory**, not advisory.

8. **Append assessment to plan file**

   Append a `## Implementation Readiness Assessment` section to the plan file using the output format below.

9. **Output visual summary**

   Generate each bar line using the render script:

   ```bash
   ./scripts/render-readiness-bar.sh "Cognitive Complexity" 3
   # Output: Cognitive Complexity     3 ■■■□□
   ./scripts/render-readiness-bar.sh "Pattern Density" 4
   # Output: Pattern Density          4 ■■■■□  ⚠
   ```

   Display a console summary with a visual bar chart:

   ```
   ══════════════════════════════════════════════
    READINESS: {feature name}
   ══════════════════════════════════════════════
    Composite: X.X/5.0 — BAND

     Cognitive Complexity    X ■■■□□
     BDD Verification        X ■■□□□
     Dependencies            X ■□□□□
     Business Impact         X ■■■■□
     Security Surface        X ■■□□□
     Pattern Density         X ■■■□□
     Performance Sensitivity X ■□□□□
     IO Boundary Breadth     X ■■□□□

    Patterns: {list, or "Standard CRUD (no special patterns)"}
    IO: {list, or "None (pure domain logic)"}
    Verdict: {one line}
    Next: {action}
   ══════════════════════════════════════════════
   ```

10. **Sync assessment to JIRA** (if JIRA integration is configured)

    Generate the ADF document using the pipeline:

    ```bash
    ./scripts/parse-plan-markdown.sh <plan-file> | ./scripts/build-adf-description.sh > /tmp/adf.json
    ```

    Then push via `~/.claude/scripts/jira-update-description.sh` (or equivalent ADF-capable API call). The ADF document must include:

    - Context paragraph (from plan)
    - Dependencies (if any)
    - Stories table (ticket, summary, status as **ADF `status` lozenge**)
    - Assessment heading with composite score + **colored emoji circle** for band
    - **Code block with the visual bar chart** — same `■□` format as the console output
    - Patterns and IO as bold-label paragraphs
    - Verdict paragraph

    **Status lozenges** (ADF `status` node in story table):

    | Status | ADF color |
    |---|---|
    | Done | `green` |
    | In Progress | `blue` |
    | To Do | `neutral` |

    ```json
    {"type": "status", "attrs": {"text": "Done", "color": "green", "style": "bold"}}
    ```

    **Readiness band circles** (ADF `emoji` node on composite score line):

    | Band | Emoji shortName |
    |---|---|
    | GREEN | `:green_circle:` |
    | BLUE | `:blue_circle:` |
    | YELLOW | `:yellow_circle:` |
    | ORANGE | `:orange_circle:` |
    | RED | `:red_circle:` |

    ```json
    [
      {"type": "text", "text": "Composite: 1.9 / 5.0 — "},
      {"type": "emoji", "attrs": {"shortName": ":blue_circle:"}},
      {"type": "text", "text": " BLUE (Manageable)", "marks": [{"type": "strong"}]}
    ]
    ```

    **Bar chart** (ADF `codeBlock` node):

    ```json
    {
      "type": "codeBlock",
      "attrs": {"language": "text"},
      "content": [{"type": "text", "text": "Cognitive Complexity    3 ■■■□□\nPattern Density         4 ■■■■□  ⚠\n..."}]
    }
    ```

    **Bar chart rendering rules:**
    - Each dimension: pad name to 24 chars, score digit, space, then `■` repeated `score` times + `□` repeated `5 - score` times
    - Dimensions scoring ≥ 4: append `  ⚠` after the bar
    - Use Unicode: `■` (U+25A0), `□` (U+25A1), `⚠` (U+26A0)

## Output Format (appended to plan file)

```markdown
## Implementation Readiness Assessment

**Assessed:** YYYY-MM-DD
**Composite Score:** X.X / 5.0 — BAND (label)

### Dimension Scores

| # | Dimension | Score | Rationale |
|---|-----------|-------|-----------|
| 1 | Cognitive Complexity | X | {one-sentence rationale} |
| 2 | BDD Verification Coverage | X | {one-sentence rationale} |
| 3 | Dependencies (Coupling) | X | {one-sentence rationale} |
| 4 | Business Impact | X | {one-sentence rationale} |
| 5 | Security Surface | X | {one-sentence rationale} |
| 6 | Pattern Density | X | {one-sentence rationale} |
| 7 | Performance Sensitivity | X | {one-sentence rationale} |
| 8 | IO Boundary Breadth | X | {one-sentence rationale} |

### Patterns Required
- {list of architectural patterns needed, or "Standard CRUD (no special patterns)"}

### IO Boundaries
- {list of IO devices/services, or "None (pure domain logic)"}

### Readiness Verdict
**BAND** — {one paragraph explaining the overall assessment and key risk areas}

### Required Preparation
{numbered list of dimension-specific actions, or "No special preparation. Proceed to `/implement-feature`."}

### Decomposition Recommendation
{present if composite > 1.5 or any dimension > 2; identify stories that need sub-task breakdown}
```

## Rules

- **Plan must exist first** — This skill operates on an existing plan. If no plan exists, instruct the user to run `/plan <feature-name>` first.
- **Every score needs rationale** — No dimension may be scored without a one-sentence justification.
- **Geometric mean is non-negotiable** — Always use the geometric mean formula. Do not average, do not use max.
- **Pattern Density must list patterns** — The rationale must name each architectural pattern counted (e.g., "repository, CQRS, event sourcing").
- **IO Boundary Breadth must list boundaries** — The rationale must name each IO boundary (e.g., "PostgreSQL, Redis, HTTP payment API").
- **Decomposition thresholds** — If composite > 1.5 OR any dimension > 2, include a Decomposition Recommendation section and suggest: "Run `/decompose <plan-id>` to break down complex stories before implementing."
- **ORANGE/RED decomposition is mandatory** — For bands ORANGE and RED, decomposition is required, not advisory. Do not proceed to `/implement-feature` without running `/decompose` first.
- **Uncertain dimensions scored conservatively** — When in doubt, score higher (more complex). It is safer to over-prepare than to under-prepare.
- **Assessment is append-only** — Append the assessment section to the plan file. Do not modify existing plan content.
- **Re-assessment replaces** — If re-running on a plan that already has an assessment, replace the existing `## Implementation Readiness Assessment` section.
- **JIRA sync is mandatory** (when configured) — After appending the assessment to the plan file, push to JIRA with the full ADF document including the visual bar chart. The repository is the source of truth; JIRA is a projection.
