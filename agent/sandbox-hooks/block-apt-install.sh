#!/usr/bin/env bash
# PreToolUse hook for Bash: deny apt/apt-get/dpkg state-changing commands.
#
# Threat model: the LLM might try to `apt-get install maven` /
# `apt-get install docker.io` on the agent (would fail today against the
# read-only rootfs, but the policy belongs at the harness layer) or on
# the builder via `ssh builder apt-get install …` (would silently
# succeed and bypass our intentional image composition). Either widens
# the sandbox's attack surface in a way the user didn't approve.
#
# We deny operations that mutate the installed-package state and allow
# read-only ones (apt list/search/show/policy, dpkg -l/--list, etc.) so
# the agent can still introspect what's already there.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# Common shell prefix/separator anchor so `sudo apt-get install`,
# `&& apt install`, `env X=y dpkg -i …`, and `ssh builder apt-get install`
# all match. The `([^[:space:]]+[[:space:]]+)*` chunk skips flag tokens
# like `-y`, `--no-install-recommends`, etc. between apt/apt-get and the
# verb.
#
# Known false positive: `grep apt-get install /some/file` matches because
# "apt-get" is preceded by a space, same as in a real invocation.
# Workaround: quote the search term — `grep "apt-get install" file`.
# Not worth the regex complexity to fix — it's a rare LLM pattern and
# the cost is just adding quotes.
ANCHOR='(^|[[:space:];|&(])'
apt_re="${ANCHOR}(apt-get|apt)[[:space:]]+([^[:space:]]+[[:space:]]+)*(install|reinstall|upgrade|full-upgrade|dist-upgrade|build-dep|remove|purge|autoremove)([[:space:]]|$)"
dpkg_re="${ANCHOR}dpkg[[:space:]]+([^[:space:]]+[[:space:]]+)*(-i|-r|-P|--install|--unpack|--remove|--purge|--configure)([[:space:]]|$)"

if printf '%s' "$cmd" | grep -qE "$apt_re|$dpkg_re"; then
  cat >&2 <<EOF
[sandbox] blocked: package-management commands are not allowed.

This sandbox composes the agent and builder images deliberately;
installing packages at runtime sidesteps that composition and widens
the attack surface invisibly. The agent's rootfs is read-only anyway,
so apt would fail there — but the same command run through SSH on the
builder would silently succeed, which is the actual hole this hook
closes.

If you need a tool that isn't installed:
  - check the builder first  -> \`ssh builder which <tool>\`
  - if it's missing there, ask the user to add it to
    builder/Dockerfile and rebuild (\`docker compose build builder\`).
  - do NOT try to apt-install it at runtime.

Read-only introspection is still allowed (\`apt list --installed\`,
\`dpkg -l\`, \`apt show <pkg>\`).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
