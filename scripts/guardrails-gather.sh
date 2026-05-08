#!/usr/bin/env bash
# guardrails-gather.sh — Gather diff context and detect guardrail violations for /check-guardrails skill
#
# Usage:
#   guardrails-gather.sh [staged|unstaged|branch]    — defaults to staged
#
# Output: JSON object with scope, changed files (with diffs and layers),
#         potential violations, and guardrails content
#
# Exit code: 0 always (AI decides severity)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec python3 - "$PROJECT_ROOT" "${1:-staged}" << 'PYEOF'
import json, subprocess, os, re, sys

project_root = sys.argv[1]
scope = sys.argv[2]
guardrails_path = os.path.join(project_root, ".claude", "guardrails.md")

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

def merge_base():
    return git("merge-base", "HEAD", "main")

# --- Phase 3a: Diff collection and layer classification ---

def get_changed_files():
    if scope == "staged":
        return git("diff", "--cached", "--name-only")
    elif scope == "unstaged":
        return git("diff", "--name-only")
    elif scope == "branch":
        base = merge_base()
        return git("diff", "--name-only", f"{base}..HEAD") if base else ""
    return ""

def get_file_diff(filepath):
    if scope == "staged":
        return git("diff", "--cached", "--", filepath)
    elif scope == "unstaged":
        return git("diff", "--", filepath)
    elif scope == "branch":
        base = merge_base()
        return git("diff", f"{base}..HEAD", "--", filepath) if base else ""
    return ""

def classify_layer(filepath):
    """Classify a file into its Clean Architecture layer by path conventions."""
    parts = filepath.lower()
    if "/domain/" in parts:
        if "/port/" in parts or "/ports/" in parts:
            return "domain-port"
        return "domain"
    if "/interactor/" in parts or "/usecase/" in parts or "/usecases/" in parts:
        return "application"
    if "/controller/" in parts or "/controllers/" in parts or "/api/" in parts:
        return "interfaces"
    if "/store/" in parts or "/stores/" in parts or "/adapter/" in parts or "/adapters/" in parts:
        return "infrastructure"
    if "/infrastructure/" in parts or "/infra/" in parts:
        return "infrastructure"
    if "/config/" in parts or "/configuration/" in parts:
        return "infrastructure"
    if "src/main/resources/" in parts or "public/" in parts or "static/" in parts:
        return "infrastructure"
    if "/component" in parts or "/page" in parts or "/view" in parts:
        return "ui"
    if "/test/" in parts or "/tests/" in parts or "/__tests__/" in parts or ".test." in parts or ".spec." in parts:
        return "test"
    if parts.endswith((".md", ".json", ".yaml", ".yml", ".xml", ".lock", ".toml")):
        return "config"
    if parts.endswith(".sh"):
        return "script"
    return "unknown"

raw_files = get_changed_files()
file_list = [f for f in raw_files.splitlines() if f.strip()]

changed_files = []
for filepath in file_list:
    diff = get_file_diff(filepath)
    layer = classify_layer(filepath)
    changed_files.append({
        "path": filepath,
        "diff": diff,
        "layer": layer
    })

# --- Phase 3b: Pattern-match IF rules ---

violations = []

for entry in changed_files:
    filepath = entry["path"]
    fpath = os.path.join(project_root, filepath)

    if not os.path.exists(fpath):
        continue

    content = read_file(fpath)
    if content is None:
        continue

    is_java = filepath.endswith(".java")
    is_ts = filepath.endswith((".ts", ".tsx"))
    is_source = is_java or is_ts or filepath.endswith((".js", ".jsx", ".py", ".go"))
    is_domain = entry["layer"] in ("domain", "domain-port")

    lines = content.splitlines()

    # IF-01: Framework imports in domain center
    if is_domain and (is_java or is_ts):
        framework_patterns = [
            r"import\s+org\.springframework",
            r"import\s+jakarta\.persistence",
            r"import\s+javax\.persistence",
            r"import\s+org\.hibernate",
            r"from\s+['\"]express['\"]",
            r"from\s+['\"]@nestjs/",
            r"from\s+['\"]typeorm['\"]",
            r"from\s+['\"]prisma['\"]",
        ]
        for i, line in enumerate(lines, 1):
            for pat in framework_patterns:
                if re.search(pat, line):
                    violations.append({"rule": "IF-01", "file": filepath, "line": i, "snippet": line.strip()[:120]})

    # IF-02: SQL string concatenation
    if is_source:
        for i, line in enumerate(lines, 1):
            if re.search(r'["\']?\s*\+.*(?:SELECT|INSERT|UPDATE|DELETE|FROM|WHERE)', line, re.IGNORECASE):
                violations.append({"rule": "IF-02", "file": filepath, "line": i, "snippet": line.strip()[:120]})

    # IF-14: Hardcoded secrets
    if is_source:
        secret_patterns = [
            r'password\s*=\s*["\'][^"\' ]+["\']',
            r'api[_-]?key\s*=\s*["\'][^"\' ]+["\']',
            r'(?:secret|token)\s*=\s*["\'][^"\' ]+["\']',
            r'(?:AKIA|sk-|ghp_|gho_|github_pat_)\w+',
        ]
        for i, line in enumerate(lines, 1):
            for pat in secret_patterns:
                if re.search(pat, line, re.IGNORECASE):
                    violations.append({"rule": "IF-14", "file": filepath, "line": i, "snippet": line.strip()[:80]})

    # IF-15: Missing /api/ prefix on controllers
    if entry["layer"] == "interfaces" and is_source:
        for i, line in enumerate(lines, 1):
            # Java: @RequestMapping or @GetMapping etc. without /api/
            if is_java and re.search(r'@(?:Request|Get|Post|Put|Delete|Patch)Mapping\s*\(\s*["\']/(?!api/)', line):
                violations.append({"rule": "IF-15", "file": filepath, "line": i, "snippet": line.strip()[:120]})
            # TS: router.get/post etc. without /api/
            if is_ts and re.search(r'\.(?:get|post|put|delete|patch)\s*\(\s*["\']/(?!api/)', line):
                violations.append({"rule": "IF-15", "file": filepath, "line": i, "snippet": line.strip()[:120]})

    # IF-06: Mutable events/models (non-final fields)
    if is_java and any(k in filepath.lower() for k in ["event", "cause", "effect", "request", "response"]):
        if "record " not in content:
            for i, line in enumerate(lines, 1):
                if re.search(r"(?:public|protected|private)\s+(?!final\s)(?!static\s)\w+\s+\w+\s*;", line):
                    violations.append({"rule": "IF-06", "file": filepath, "line": i, "snippet": line.strip()[:120]})

# --- Assemble output ---

guardrails_content = read_file(guardrails_path)

output = {
    "scope": scope,
    "changedFiles": changed_files,
    "potentialViolations": violations,
    "guardrailsContent": guardrails_content
}

print(json.dumps({"success": True, "data": output}, indent=2))
PYEOF
