# /commit - Git Commit Workflow

Prepare and create a git commit following project conventions.

> **Script:** `./scripts/commit-helper.sh` — invoke directly for zero-token execution.

## Workflow

1. **Run gather script:**

   ```bash
   ./scripts/commit-gather.sh
   ```

   This produces a JSON object with:
   - `status` — array of `{path, status}` from `git status --porcelain`
   - `diffStat` — `git diff --stat` output
   - `fullDiff` — staged and unstaged diffs (labeled sections)
   - `inProgressPlanCount` — number of in-progress plans (for unplanned work detection)
   - `lastCommitMessage` — last commit subject
   - `recentCommitSubjects` — last 5 commit subjects (for convention matching)

2. **Analyze changes from JSON and decide staging:**

   Review `status` and `fullDiff` to determine which files to stage. Never use `git add -A` or `git add .`:

   ```bash
   git add <specific-files>
   ```

3. **Create commit with heredoc** for proper formatting:

   ```bash
   git commit -m "$(cat <<'EOF'
   <type>: <short description>

   <optional body explaining the why>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

   Match the commit convention from `recentCommitSubjects`.

4. **Verify commit:**

   ```bash
   git status
   git log --oneline -1
   ```

5. **Track unplanned work** (after successful commit):

   If `inProgressPlanCount` is **0**, this is unplanned work:
   - Derive a slug from the commit subject: lowercase, spaces/special chars to hyphens, max 50 chars
   - Create `plans/results/YYYY-MM-DD-<slug>.md` with this template:

     ```markdown
     # <Commit Subject> - Unplanned Change

     ## Summary

     <Brief description derived from commit message>

     ## Files Changed

     <List files from the commit>

     ## Quality Gates

     - [x] Pre-commit hooks passed
     ```

   - Register in plan index:
     ```bash
     ./scripts/plan-index.sh add "<commit subject>" "" "unplanned" "plans/results/YYYY-MM-DD-<slug>.md"
     ```
   - Amend the commit to include the tracking files:
     ```bash
     git add plans/results/<file> plans/index.json && git commit --amend --no-edit
     ```

   If `inProgressPlanCount` is **greater than 0**, skip — the work is planned.

## Commit Message Format

- First line: `<type>: <description>` (max 70 chars)
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`
- Body: Explain "why" not "what"
- Always include Co-Authored-By line

## Rules

- NEVER commit without reviewing the `fullDiff` from the gather output first
- NEVER use `git add -A` or `git add .`
- NEVER commit .env or credential files
- Never commit environment-specific values (URLs, credentials, ports)
- Integrate to trunk at minimum daily — if work is not ready, commit with `WIP:` prefix
- Pre-commit hook will run automatically
