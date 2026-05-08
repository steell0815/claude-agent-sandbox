# /push - Push to Remote

Push commits to the remote repository.

## Workflow

1. **Check remote pipeline status:**

   ```bash
   gh run list --branch main --limit 1
   ```

   - If the latest run **failed**, halt and warn: "Remote main pipeline is red. Only push if this change is specifically a fix for the broken pipeline."
   - If the latest run **passed** or no runs exist, proceed.

2. **Verify local state:**

   ```bash
   git status
   git log --oneline origin/main..HEAD
   ```

3. **Push to remote:**

   ```bash
   git push origin main
   ```

4. **Verify push succeeded** by checking output for errors.

## Rules

- Pipeline is the only path to production — never bypass the pipeline
- Check pipeline status before pushing — do not push on top of a red pipeline unless fixing it
- NEVER force push to main/master
- Ensure all commits have passed pre-commit hooks
- Report the GitHub Actions URL for CI monitoring if relevant
