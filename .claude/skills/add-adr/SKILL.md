# /add-adr - Create Architecture Decision Record

Create a new ADR following the project template and register it in the ADR index.

## Arguments

- `<title>`: The title of the architectural decision

## Workflow

1. **Determine next ADR number**

   Read `docs/adr/adr.md` and find the highest existing ADR number. The new ADR is that number + 1.

   ```bash
   ls docs/adr/adr-*.md | sort -t- -k2 -n | tail -1
   ```

2. **Generate filename**

   ```
   docs/adr/adr-{NNN}-{slug}.md
   ```

   Where `{NNN}` is the zero-padded ADR number and `{slug}` is the title converted to lowercase with spaces replaced by hyphens.

3. **Create ADR from template**

   Read `docs/adr/adr-000-template.md` and create the new file with:

   - Title: `# ADR-{NNN}: {Title}`
   - Status: `Proposed`
   - Context: Fill in based on discussion with the user — what problem or decision prompted this?
   - Decision: Fill in the chosen approach and key constraints
   - Consequences: Fill in Positive, Negative, and Neutral sections

   Use abstract, technology-agnostic language. Include pseudocode examples where they clarify the decision. Avoid framework-specific references.

4. **Update ADR index**

   Add the new entry to the table in `docs/adr/adr.md`:

   ```markdown
   | [ADR-{NNN}](adr-{NNN}-{slug}.md) | {Title} | Proposed | {YYYY-MM-DD} |
   ```

5. **Output**

   Display the created file path, ADR number, and a summary of the decision.

## Example

```
/add-adr Use Event Sourcing for Order Entity
```

Creates `docs/adr/adr-014-use-event-sourcing-for-order-entity.md` and adds it to the index.

## Rules

- ADR numbers are sequential and never reused
- New ADRs start with status `Proposed` — they become `Accepted` after team review
- Use technology-agnostic language (pseudocode, not framework-specific code)
- Every ADR must have all three consequence sections (Positive, Negative, Neutral)
- If the decision is architectural (affects layer structure, dependency rules, or patterns), check if `.claude/guardrails.md` should also be updated and suggest running `/add-guardrail`
