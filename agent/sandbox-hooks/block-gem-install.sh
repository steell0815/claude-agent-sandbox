#!/usr/bin/env bash
# PreToolUse hook for Bash: deny gem state-changing commands.
#
# Threat: same as the other install-family hooks — `gem install <pkg>`
# installs into the active Ruby's gem path, extending the runtime
# image outside its Dockerfile.
#
# Coverage:
#   - gem install / uninstall / update             (incl. --system)
#   - gem cleanup
#
# Read-only inspection (`gem list`, `gem search`, `gem info`, `gem env`,
# `gem which`, `gem --version`, etc.) stays allowed.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

GEM_RE='(^|[[:space:];|&(])gem[[:space:]]+(install|uninstall|update|cleanup|pristine)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$GEM_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: \`gem install\` (and other state-changing gem
commands) is not allowed.

Same shape as the other install hooks: extends the runtime image
outside its Dockerfile. Agent rootfs is read-only here; ssh-builder
forwarding would silently mutate the builder.

If you need a Ruby gem that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <bin>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for project-local deps, use Bundler — \`bundle install\` (with a
    project Gemfile inside /workspace) writes to the project's
    bundle path, not the system gem path. (\`bundle\` is not blocked.)

Read-only inspection is still allowed (\`gem list\`, \`gem search\`,
\`gem info\`, \`gem env\`, \`gem which\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
