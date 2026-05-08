# Knowledge Harvesting

Knowledge harvesting is the practice of maintaining AI-readable domain memory files so that every development session starts with full context and ends with updated knowledge.

## Rules

### READ FIRST

Before starting any domain work, read the feature knowledge file:

```
.claude/features/{domain}.md
```

If the file exists, read it completely before making any changes. It contains:
- Key type contracts and relationships
- File locations for all related code
- Architecture notes and design decisions
- API endpoints and their behavior
- Known gotchas and edge cases

### WRITE BACK

After completing domain work, update the feature knowledge file with:
- Any new files created or modified
- New type contracts or API endpoints
- Design decisions made during implementation
- Gotchas discovered during development
- Changes to architecture or data flow

### CREATE NEW

If no feature knowledge file exists for the domain you're working in:
1. Create `.claude/features/{domain}.md` using the [template](features/TEMPLATE.md)
2. Populate it with everything you learned during implementation
3. Include all file paths, type contracts, and architecture notes

## What to Document

| Document | Skip |
|----------|------|
| Type contracts (fields, types, constraints) | Implementation details that are obvious from code |
| File paths for all related code | Temporary debugging notes |
| API endpoint paths and methods | Personal preferences or opinions |
| Relationships between entities | Information already in ADRs or CLAUDE.md |
| Non-obvious design decisions | Boilerplate patterns documented in layer docs |
| Known gotchas and workarounds | Version-specific framework bugs (put in ADR instead) |
| State machine transitions | Test data or fixtures |
| Event flows between bounded contexts | |

## File Organization

```
.claude/features/
  TEMPLATE.md          # Template for new feature docs
  {domain-name}.md     # One file per bounded context / feature area
  .gitkeep             # Placeholder for empty directory
```

Use kebab-case for file names. One file per bounded context or major feature area. If a feature spans multiple bounded contexts, document it in the primary context's file and cross-reference from others.

## When to Harvest

- After completing a new feature implementation
- After fixing a non-trivial bug (document the root cause and fix)
- After adding or modifying API endpoints
- After changing domain model structure
- After discovering a gotcha that would waste future time
- Use the `/harvest-knowledge` skill to automate this process
