# Coverage Exclusions

This file documents intentional exclusions from coverage and mutation testing thresholds defined in [guardrails GR-09](../.claude/guardrails.md). Each entry records code that cannot reasonably meet its circle's target due to sound design choices, along with the alternative verification that provides confidence in that code.

Exclusions are reviewed as part of the normal code review process.

| Code Area | Circle | Reason | Alternative Verification | Date | Reviewer |
|-----------|--------|--------|--------------------------|------|----------|
| `generated/mappers/` | Adapters | Auto-generated mapper code; writing unit tests would test the generator, not business logic | Integration tests verify correct mapping end-to-end | 2025-01-01 | (example) |
