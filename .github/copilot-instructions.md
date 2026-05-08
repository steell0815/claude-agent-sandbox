# Copilot Instructions (Repository)

## Non-negotiables
- Prefer readability over cleverness.
- Follow strict TDD:
    - Write/modify a failing test first.
    - Make it pass with the simplest code.
    - Refactor with tests green.
- If I ask for a design, propose test-first steps and the smallest incremental path.
- Every piece of code must work correctly AND be easy to change.
- Loose coupling is non-negotiable; flag changes that increase coupling.
- Refactoring = internal structure change without behavior change. Do not conflate it with rewriting or fixing.
- Warn me explicitly if my request introduces:
    - flaky tests
    - hidden coupling
    - leaky abstractions
    - security risks
    - overengineering

## BDD acceptance testing (4 layers)
We use: Test -> DSL -> Driver -> System Under Test (SUT).
- Acceptance tests express intent, not mechanics.
- DSL is domain language, stable, and re-usable.
- Driver handles IO/protocol/UI boundaries.
- SUT is the application/service under test.

## Domain-driven design
- Use the ubiquitous language from `docs/glossary.md`.
- If you introduce a new domain term, propose a glossary entry.

## Coding style
- Small functions, meaningful names, no clever one-liners.
- Prefer explicit code over magic.
- Keep dependencies injectable/testable.
- No changes without tests unless explicitly requested.

## Design principles
- **SRP**: One reason to change per module. If a class has multiple responsibilities, split it.
- **OCP**: Extend behavior by composition, not by modifying existing code.
- **DIP**: Domain owns interfaces; adapters implement them. Never let the domain import infrastructure.
- **Coupling & Cohesion**: Group code by shared intent, not technical layer. Flag violations when you see them.

## Output expectations
- When generating code, also propose:
    - the tests you added
    - edge cases
    - minimal refactoring follow-up
