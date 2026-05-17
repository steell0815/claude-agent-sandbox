#!/usr/bin/env bash
# PreToolUse hook for Bash: deny `go install` / `go get`.
#
# Threat: same as the other install-family hooks — `go install <pkg>`
# writes a binary to $GOBIN (default ~/go/bin), extending the runtime
# image outside its Dockerfile. The agent's read-only rootfs blocks it
# locally, but `ssh builder go install …` would silently succeed.
#
# Coverage:
#   - go install <pkg>                  (current)
#   - go install <pkg>@version
#   - go install ./...                  (install module's binaries)
#   - go get <pkg>                      (legacy; still works pre-1.18 modes)
#
# Read-only / project-scoped operations stay allowed: build, run, test,
# vet, fmt, mod (incl. mod tidy / mod download — those write to the
# module cache only), list, env, version, tool, doc, generate, etc.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

GO_RE='(^|[[:space:];|&(])go[[:space:]]+(install|get)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$GO_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: \`go install\` / \`go get\` is not allowed.

\`go install\` writes a binary to \$GOBIN (default ~/go/bin),
extending the runtime image outside its Dockerfile. Same story as
the other install-family hooks. The agent rootfs is read-only so it
fails here; \`ssh builder go install …\` would succeed and quietly
widen the builder.

If you need a Go binary that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <bin>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for in-project builds, \`go build\` writes to the current
    directory (./<binary>), and \`go run ./cmd/foo\` runs without
    installing — both stay allowed.

Read-only / project-scoped operations are still allowed
(\`go build\`, \`run\`, \`test\`, \`vet\`, \`fmt\`, \`mod\`, \`list\`,
\`env\`, \`tool\`, \`doc\`, \`generate\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
