# /harvest-knowledge - Update Feature Knowledge File

Create or update the domain knowledge file for a feature area after completing development work.

## Arguments

- `<domain>` (optional): The domain/feature name. If omitted, the script infers from recent changes.

## Workflow

1. **Run gather script:**

   ```bash
   ./scripts/harvest-gather.sh [domain]
   ```

   This produces a JSON object with:
   - `domain` — detected or specified domain name
   - `existingKnowledge` — current content of `.claude/features/{domain}.md` (or template if new)
   - `fileManifest` — all files related to this domain across all layers
   - `entities` — extracted entity/VO names, files, and field snippets
   - `events` — extracted event type names (Cause/Effect patterns) and files
   - `endpoints` — extracted HTTP endpoints (method, path, file)

2. **Synthesize the knowledge file**

   Using the gathered data, write or update `.claude/features/{domain}.md`:

   - **Key Type Contracts**: Populate from `entities` — document fields, types, and constraints
   - **File Manifest**: Use `fileManifest` directly — organize by layer
   - **Architecture Notes**: Infer from the file organization and entity relationships
   - **API Endpoints**: Populate from `endpoints` — include method, path, description
   - **Domain Events**: Populate from `events` — document cause/effect pairs
   - **Gotchas / Notes**: Identify non-obvious behaviors from the code structure

3. **Update vs. create logic**

   If `existingKnowledge` contains real content (not the template):
   - Preserve existing sections that are still accurate
   - Update sections where entities/endpoints/events have changed
   - Add new entries for newly discovered types or endpoints
   - Update the "Last updated" date

   If `existingKnowledge` is the template or null:
   - Fill in all sections from the template
   - Remove placeholder rows that don't apply

4. **Output**

   Display:
   - The file path created/updated
   - A summary of what was documented
   - Any sections that may need manual review (e.g., if domain was auto-detected as "unknown")

## Rules

- Always read the `existingKnowledge` field before writing — preserve accurate existing content
- Document facts, not opinions — type contracts, file paths, API endpoints
- Use the same naming conventions as the codebase (don't rename things in docs)
- Keep entries concise — this is a reference, not a tutorial
- If domain was auto-detected as "unknown", warn the user and ask for clarification
- If a domain spans multiple bounded contexts, document in the primary context and cross-reference
