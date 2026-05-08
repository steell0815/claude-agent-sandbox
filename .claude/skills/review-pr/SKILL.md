# /review-pr - Pull Request Review

Review a pull request against project standards and conventions.

## Arguments

- `<pr-number>` or `<pr-url>`: The PR to review

## Workflow

1. **Fetch PR Details**

   ```bash
   gh pr view <pr-number> --json title,body,files,additions,deletions,commits
   gh pr diff <pr-number>
   ```

2. **Review Checklist**

   Evaluate the PR against each criterion:

   ### Code Quality
   - [ ] Follows TDD (tests exist for new functionality)
   - [ ] No source code comments (except regex, workarounds, non-obvious algorithms)
   - [ ] Small functions with meaningful names
   - [ ] Readability over cleverness

   ### Architecture
   - [ ] Clean Architecture patterns respected (entities, value objects, interactors)
   - [ ] No infrastructure leakage into domain layer
   - [ ] Ubiquitous language used consistently

   ### Testing
   - [ ] Unit tests cover new/changed behavior
   - [ ] BDD acceptance tests updated if user-facing
   - [ ] Test structure follows 4-layer pattern (Test → DSL → Driver → SUT)
   - [ ] No flaky test patterns (sleeps, timing dependencies)

   ### Security
   - [ ] No secrets or credentials in code
   - [ ] Input validation at system boundaries
   - [ ] No new security vulnerabilities (XSS, injection, SSRF, etc.)
   - [ ] Auth/authz changes flagged and reviewed

   ### Delivery (Minimum CD)
   - [ ] No hardcoded environment-specific configuration
   - [ ] Changes are rollback-safe (no irreversible migrations without versioning)
   - [ ] No manual deployment steps introduced
   - [ ] Artifact immutability preserved

   ### Conventions
   - [ ] Commit messages follow format (`<type>: <description>`)
   - [ ] No unnecessary files committed (.env, build artifacts)
   - [ ] Glossary updated if new domain terms introduced

3. **Generate Review**

   Post a structured review comment:

   ```bash
   gh pr review <pr-number> --comment --body "$(cat <<'EOF'
   ## PR Review

   ### Summary
   <Brief assessment>

   ### Checklist
   <Results from above>

   ### Issues Found
   <List of concerns, if any>

   ### Suggestions
   <Optional improvements>
   EOF
   )"
   ```

## Review Verdicts

- **Approve**: All checks pass, no issues found
- **Request Changes**: Critical issues that must be fixed
- **Comment**: Minor suggestions or questions

## Rules

- Always review the full diff, not just file names
- Flag security concerns even if they seem minor
- Suggest specific improvements, not vague feedback
