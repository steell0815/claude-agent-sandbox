# agents.md

## How to work in this repo
- Always start by locating/creating the relevant tests.
- Never bypass acceptance-test layering (Test -> DSL -> Driver -> SUT).
- Keep changes minimal and incremental; stop after each green test milestone.
- If uncertain, ask by presenting 2 options with tradeoffs (but still propose a default).

## Safety & security
- Treat security as first-class. Prefer safe defaults.
- Flag: authn/authz changes, input validation gaps, deserialization, SSRF, XSS, SQLi, secrets.

## Documentation
- Update `docs/glossary.md` when introducing new domain terms.
- Update checklists if a new repeated pattern emerges.
