#!/usr/bin/env bash
# PreToolUse hook for Bash: deny global installs in the node ecosystem
# (npm, pnpm, yarn).
#
# Threat: same as the apt and docker hooks — globally installing a
# package extends the runtime image outside its Dockerfile. On the
# agent the read-only rootfs would reject it; via `ssh builder …` it
# silently succeeds and quietly widens the builder.
#
# Coverage:
#   npm   install -g / i -g / install --global   (any flag order)
#   pnpm  add -g     / install -g / i -g         (any flag order)
#   yarn  global add / global remove / global upgrade   (yarn classic v1)
#
# Read-only inspection (`npm list -g`, `pnpm list -g`, `yarn global list`,
# `yarn global bin`, etc.) stays allowed.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).
#
# Known false positive: deny pattern inside a literal string (e.g.
# `echo "npm install -g foo"`) matches because anchoring on whitespace
# doesn't distinguish quoted contexts. Workaround is rephrasing; same
# edge case as the apt and docker hooks.

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# npm + pnpm share the same shape: install/add/i with -g or --global,
# possibly with other flags or positional packages between the verb
# and the flag. `[^;|&()]` keeps the match from spanning chained
# commands.
NPM_PNPM_RE='(^|[[:space:];|&(])(npm|pnpm)[[:space:]]+(install|add|i)[[:space:]]+([^;|&()]+[[:space:]])?(-g|--global)([[:space:]]|$)'

# yarn classic uses a `global` subcommand before the verb.
YARN_RE='(^|[[:space:];|&(])yarn[[:space:]]+global[[:space:]]+(add|remove|upgrade)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$NPM_PNPM_RE|$YARN_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: global node-package installs are not allowed.

This covers:
  - npm install -g  / npm i -g  / --global
  - pnpm add -g     / pnpm install -g  / --global
  - yarn global add / global remove / global upgrade

Globally installing at runtime sidesteps the deliberate image
composition (agent has Claude Code's bundled node deps; builder has
the project toolchain) and silently mutates whichever container the
command runs in. The agent's rootfs is read-only so it fails there
anyway, but the same command via \`ssh builder …\` would succeed
and quietly widen the builder.

If you need a node tool that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <tool>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for project-local deps, use \`<pm> install <pkg>\` (no -g) inside
    /workspace — that writes to node_modules, not the global prefix.

Read-only inspection is still allowed (\`npm list -g\`, \`pnpm list -g\`,
\`yarn global list\`, \`yarn global bin\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
