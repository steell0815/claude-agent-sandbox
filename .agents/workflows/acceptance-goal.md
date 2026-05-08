# Acceptance Goal Workflow

## Purpose

This workflow describes how to make one or more acceptance tests pass, coordinating work across backend, frontend, and acceptance agents.

## Steps

### 1. Analyze (module-coordinator)
- Parse the goal and identify which acceptance tests need to pass
- Read the relevant DSL interfaces to understand required methods
- Decompose into backend, frontend, and acceptance tasks

### 2. Backend Implementation (backend-agent)
- Implement domain changes (entities, value objects, interactors)
- Update API endpoints/controllers as needed
- Ensure unit tests pass for all changes
- Can run in parallel with frontend

### 3. Frontend Implementation (frontend-agent)
- Implement UI components and pages
- Integrate with backend APIs
- Handle i18n and accessibility
- Can run in parallel with backend

### 4. Acceptance Test Updates (acceptance-agent)
- Update DSL methods if new capabilities needed
- Update protocol drivers (Domain, Controller, UI)
- Verify all test variants pass

### 5. Validation (all validators)
- backend-validator: Clean Architecture compliance, security, immutability
- frontend-validator: a11y, i18n, linting
- dsl-validator: BDD patterns, no flaky tests

### 6. Test (module-coordinator)
- Run full acceptance test suite
- If tests fail, iterate from step 2
- Run regression tests for the module

### 7. Complete (module-coordinator)
- Prepare commit using commit-preparer.sh
- Update plan status
- Create summary in results.md
