#!/usr/bin/env bash
# init-gather.sh — Gather session context for /init skill
#
# Usage:
#   init-gather.sh
#
# Output: JSON object with branch, recent commits, plan status, feature files, session model
#
# Exit code: 0 always (missing data produces null/empty fields, not errors)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec python3 - "$PROJECT_ROOT" << 'PYEOF'
import json, subprocess, os, re, sys

project_root = sys.argv[1]
index_file = os.path.join(project_root, "plans", "index.json")
session_model_path = os.path.join(project_root, ".claude", "session-model.md")
features_dir = os.path.join(project_root, ".claude", "features")

def git(*args):
    try:
        result = subprocess.run(
            ["git", "-C", project_root] + list(args),
            capture_output=True, text=True, timeout=10
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

# 1. Branch
branch = git("branch", "--show-current")

# 2. Recent commits
recent_commits = []
log_output = git("log", "--oneline", "-5", "--format=%h||%s")
for line in log_output.splitlines():
    if "||" in line:
        h, m = line.split("||", 1)
        recent_commits.append({"hash": h, "message": m})

# 3. Last commit metadata
last_time = git("log", "-1", "--format=%ar")
last_msg = git("log", "-1", "--format=%s")

# 4. Plan status
in_progress_plan = None
planned_plans = []

index_content = read_file(index_file)
if index_content:
    try:
        index_data = json.loads(index_content)
        for p in index_data.get("plans", []):
            if p.get("status") == "in_progress" and p.get("file") and not in_progress_plan:
                plan_path = os.path.join(project_root, p["file"])
                plan_content = read_file(plan_path) or ""
                phases = re.findall(r"^### Phase \d+", plan_content, re.MULTILINE)
                total = len(phases)
                log_section = ""
                if "## Implementation Log" in plan_content:
                    log_section = plan_content[plan_content.index("## Implementation Log"):]
                log_entries = re.findall(r"^### Phase (\d+):", log_section, re.MULTILINE)
                current = (int(log_entries[-1]) + 1) if log_entries else 1
                in_progress_plan = {
                    "id": p["id"],
                    "title": p["title"],
                    "file": p["file"],
                    "currentPhase": min(current, total),
                    "totalPhases": total
                }
            elif p.get("status") == "planned":
                planned_plans.append({
                    "id": p["id"],
                    "title": p["title"],
                    "file": p.get("file", "")
                })
    except (json.JSONDecodeError, KeyError):
        pass

# 5. Feature files
feature_files = []
if os.path.isdir(features_dir):
    feature_files = sorted([
        f for f in os.listdir(features_dir)
        if f.endswith(".md") and f != "TEMPLATE.md"
    ])

# 6. Session model
session_model = read_file(session_model_path)

# Assemble output
output = {
    "branch": branch,
    "recentCommits": recent_commits,
    "inProgressPlan": in_progress_plan,
    "plannedPlans": planned_plans,
    "featureFiles": feature_files,
    "sessionModel": session_model,
    "lastCommitTime": last_time,
    "lastCommitMessage": last_msg
}

print(json.dumps({"success": True, "data": output}, indent=2))
PYEOF
