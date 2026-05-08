#!/usr/bin/env bash
# commit-gather.sh — Gather commit context for /commit skill
#
# Usage:
#   commit-gather.sh
#
# Output: JSON object with git status, diff stat, full diff, plan index, last commit message
#
# Exit code: 0 always

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec python3 - "$PROJECT_ROOT" << 'PYEOF'
import json, subprocess, os, sys

project_root = sys.argv[1]
index_file = os.path.join(project_root, "plans", "index.json")

def git(*args):
    try:
        result = subprocess.run(
            ["git", "-C", project_root] + list(args),
            capture_output=True, text=True, timeout=30
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""

def read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except (FileNotFoundError, PermissionError):
        return None

# 1. Git status (porcelain for machine parsing)
status_lines = []
raw_status = git("status", "--porcelain")
for line in raw_status.splitlines():
    if len(line) >= 3:
        code = line[:2].strip()
        path = line[3:]
        status_lines.append({"path": path, "status": code})

# 2. Diff stat
diff_stat = git("diff", "--stat")

# 3. Full diff (staged + unstaged)
staged_diff = git("diff", "--cached")
unstaged_diff = git("diff")
full_diff = ""
if staged_diff:
    full_diff += "=== STAGED ===\n" + staged_diff
if unstaged_diff:
    if full_diff:
        full_diff += "\n\n"
    full_diff += "=== UNSTAGED ===\n" + unstaged_diff

# 4. Plan index — just in-progress count for unplanned work detection
in_progress_count = 0
index_content = read_file(index_file)
if index_content:
    try:
        index_data = json.loads(index_content)
        in_progress_count = sum(
            1 for p in index_data.get("plans", [])
            if p.get("status") == "in_progress"
        )
    except (json.JSONDecodeError, KeyError):
        pass

# 5. Last commit message (for style matching)
last_commit = git("log", "-1", "--format=%s")

# 6. Recent commit messages (for convention detection)
recent_subjects = []
log_output = git("log", "--oneline", "-5", "--format=%s")
for line in log_output.splitlines():
    if line.strip():
        recent_subjects.append(line.strip())

output = {
    "status": status_lines,
    "diffStat": diff_stat,
    "fullDiff": full_diff,
    "inProgressPlanCount": in_progress_count,
    "lastCommitMessage": last_commit,
    "recentCommitSubjects": recent_subjects
}

print(json.dumps({"success": True, "data": output}, indent=2))
PYEOF
