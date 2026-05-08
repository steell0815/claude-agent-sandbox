#!/usr/bin/env bash
# harvest-gather.sh — Gather domain knowledge context for /harvest-knowledge skill
#
# Usage:
#   harvest-gather.sh [domain]
#
# If domain is omitted, attempts to detect from recent git changes.
#
# Output: JSON object with domain, existing knowledge, file manifest, entities, events, endpoints
#
# Exit code: 0 always

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec python3 - "$PROJECT_ROOT" "${1:-}" << 'PYEOF'
import json, subprocess, os, re, sys, glob as globmod

project_root = sys.argv[1]
domain_arg = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
features_dir = os.path.join(project_root, ".claude", "features")
template_path = os.path.join(features_dir, "TEMPLATE.md")

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

def find_files(pattern):
    """Find files matching a glob pattern relative to project root."""
    matches = []
    for path in globmod.glob(os.path.join(project_root, pattern), recursive=True):
        rel = os.path.relpath(path, project_root)
        if ".git/" not in rel and "node_modules/" not in rel and "__pycache__/" not in rel:
            matches.append(rel)
    return sorted(matches)

# 1. Domain detection
domain = domain_arg

if not domain:
    # Infer from recent git diff
    diff_files = git("diff", "--name-only", "HEAD~1").splitlines()
    if not diff_files:
        diff_files = git("diff", "--name-only").splitlines()

    # Extract domain from path patterns like src/domain/<domain>/ or src/<domain>/domain/
    domain_candidates = {}
    for f in diff_files:
        parts = f.split("/")
        for i, part in enumerate(parts):
            if part == "domain" and i + 1 < len(parts):
                candidate = parts[i + 1]
                if candidate not in ("port", "ports", "event", "events", "service", "services"):
                    domain_candidates[candidate] = domain_candidates.get(candidate, 0) + 1
    if domain_candidates:
        domain = max(domain_candidates, key=domain_candidates.get)

if not domain:
    domain = "unknown"

# 2. Existing knowledge file
knowledge_path = os.path.join(features_dir, f"{domain}.md")
existing_knowledge = read_file(knowledge_path)
if existing_knowledge is None:
    existing_knowledge = read_file(template_path)

# 3. File manifest — files related to this domain
manifest_patterns = [
    f"**/domain/{domain}/**",
    f"**/domain/{domain}.*",
    f"**/{domain}/**/*.java",
    f"**/{domain}/**/*.ts",
    f"**/{domain}/**/*.tsx",
    f"**/acceptance/{domain}*/**",
    f"**/acceptance/*{domain}*/**",
]
file_manifest = []
seen = set()
for pattern in manifest_patterns:
    for f in find_files(pattern):
        if f not in seen:
            file_manifest.append(f)
            seen.add(f)

# 4. Entity extraction — find classes/interfaces that look like entities or value objects
entities = []
entity_patterns = [
    # Java: class/record with entity-like names
    (r"(?:public\s+)?(?:class|record|interface)\s+(\w+)", ".java"),
    # TypeScript: class/interface exports
    (r"export\s+(?:class|interface)\s+(\w+)", ".ts"),
]

for f in file_manifest:
    fpath = os.path.join(project_root, f)
    content = read_file(fpath)
    if content is None:
        continue
    for pattern, ext in entity_patterns:
        if not f.endswith(ext):
            continue
        if "/domain/" in f or "/entity/" in f or "/model/" in f:
            for match in re.finditer(pattern, content):
                name = match.group(1)
                # Extract a snippet of fields (first 5 field-like lines)
                field_lines = []
                for line in content.splitlines():
                    line_stripped = line.strip()
                    if re.match(r"(?:private|public|protected|readonly)\s+\w+", line_stripped):
                        field_lines.append(line_stripped)
                    if len(field_lines) >= 5:
                        break
                entities.append({
                    "name": name,
                    "file": f,
                    "fields": "\n".join(field_lines) if field_lines else "(no fields extracted)"
                })

# 5. Event extraction
events = []
for f in file_manifest:
    content = read_file(os.path.join(project_root, f))
    if content is None:
        continue
    if "/event/" in f or "/events/" in f or "Event" in f or "Cause" in f or "Effect" in f:
        # Java records/classes
        for match in re.finditer(r"(?:public\s+)?(?:record|class)\s+(\w+(?:Event|Cause|Effect)\w*)", content):
            events.append({"name": match.group(1), "file": f})
        # TS types/interfaces
        for match in re.finditer(r"export\s+(?:type|interface)\s+(\w+(?:Event|Cause|Effect)\w*)", content):
            events.append({"name": match.group(1), "file": f})

# 6. Endpoint extraction
endpoints = []
for f in file_manifest:
    content = read_file(os.path.join(project_root, f))
    if content is None:
        continue
    if "/controller/" in f or "/controllers/" in f or "/api/" in f or "Controller" in f or "router" in f.lower():
        # Java @XxxMapping annotations
        for match in re.finditer(r'@(Get|Post|Put|Delete|Patch)Mapping\s*\(\s*["\']([^"\']+)["\']', content):
            endpoints.append({"method": match.group(1).upper(), "path": match.group(2), "file": f})
        for match in re.finditer(r'@RequestMapping\s*\(\s*["\']([^"\']+)["\']', content):
            endpoints.append({"method": "REQUEST", "path": match.group(1), "file": f})
        # Express/TS router
        for match in re.finditer(r'\.(?:get|post|put|delete|patch)\s*\(\s*["\']([^"\']+)["\']', content):
            method = match.group(0).split(".")[1].split("(")[0].upper()
            endpoints.append({"method": method, "path": match.group(1), "file": f})

output = {
    "domain": domain,
    "existingKnowledge": existing_knowledge,
    "fileManifest": file_manifest,
    "entities": entities,
    "events": events,
    "endpoints": endpoints
}

print(json.dumps({"success": True, "data": output}, indent=2))
PYEOF
