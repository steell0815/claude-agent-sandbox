#!/usr/bin/env bash
# PreToolUse hook for Bash: deny `npm install -g`.
#
# Threat model: the LLM (or anything it shells out to — package.json
# postinstall scripts, git hooks, etc.) might try to globally install
# a node tool to plug a perceived gap. On the agent this fails against
# the read-only rootfs; on the builder (via `ssh builder npm install
# -g …`) it silently succeeds and quietly widens the builder image.
# Same shape as the apt and docker hooks: extending the runtime image
# at build-time of a session is exactly what we don't want.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).
#
# Known false positive: `echo "npm install -g foo"` (the deny pattern
# inside a literal string) matches because anchoring on whitespace
# doesn't distinguish quoted contexts. Workaround: don't print the
# command verbatim; or escape the dashes. Same edge-case shape as
# the apt and docker hooks — not worth the regex complexity to fix.

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# Match `npm <space> (install|i) <space> [args]* (-g|--global)` where the
# args run is restricted to non-separator chars so the match can't span
# multiple piped/chained commands. `(install|i)` covers both spellings.
# (-g|--global) can appear immediately after the subcommand (`npm install
# -g foo`) or after positional packages (`npm install foo -g`).
deny_re='(^|[[:space:];|&(])npm[[:space:]]+(install|i)[[:space:]]+([^;|&()]+[[:space:]])?(-g|--global)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$deny_re"; then
  cat >&2 <<EOF
[sandbox] blocked: \`npm install -g\` is not allowed.

Globally installing node packages at runtime sidesteps the deliberate
image composition (agent has Claude Code's bundled node deps; builder
has pnpm + the project toolchain) and silently mutates whichever
container the command runs in. The agent's rootfs is read-only so it
would fail there anyway, but the same command run via \`ssh builder
npm install -g …\` would succeed and quietly widen the builder.

If you need a node tool that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <tool>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for project-local deps, use \`npm install <pkg>\` (no -g) inside
    /workspace — that writes to node_modules, not the global prefix,
    and is the right way to add a runtime dependency.

Read-only inspection is still allowed (\`npm list -g\`, \`npm view\`,
\`npm config get prefix\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
