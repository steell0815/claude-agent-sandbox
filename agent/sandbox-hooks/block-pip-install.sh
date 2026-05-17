#!/usr/bin/env bash
# PreToolUse hook for Bash: deny pip/pipx state-changing commands.
#
# Threat: same as the apt and node hooks — installing a Python tool at
# runtime sidesteps the image composition. On the agent the read-only
# rootfs would reject a system-wide install, but `pip install --user`
# writes to ~/.local (a tmpfs) and the same `ssh builder pip install
# --user …` succeeds and mutates the builder's home dir.
#
# Coverage:
#   pip   install / uninstall / download         (pip / pip3)
#   python -m pip install / uninstall / download (and python3)
#   pipx  install / uninstall / upgrade(-all) / reinstall(-all)
#
# Read-only inspection (`pip list`, `pip show`, `pip freeze`,
# `pip cache list`, `pipx list`, etc.) stays allowed.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# Direct pip / pip3 invocations.
PIP_RE='(^|[[:space:];|&(])pip3?[[:space:]]+(install|uninstall|download)([[:space:]]|$)'

# `python -m pip <verb>` / `python3 -m pip <verb>`. Allow either spelling
# of -m (separated by space or fused, e.g. `python -mpip`).
PY_PIP_RE='(^|[[:space:];|&(])python3?[[:space:]]+(-m[[:space:]]+pip|-mpip)[[:space:]]+(install|uninstall|download)([[:space:]]|$)'

# pipx (separate tool, installs CLI tools into their own venvs).
PIPX_RE='(^|[[:space:];|&(])pipx[[:space:]]+(install|uninstall|upgrade|upgrade-all|reinstall|reinstall-all)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$PIP_RE|$PY_PIP_RE|$PIPX_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: pip / pipx installs are not allowed.

This covers:
  - pip install / uninstall / download   (also pip3)
  - python -m pip install / …            (also python3)
  - pipx install / uninstall / upgrade / reinstall

Globally — or even per-user — installing Python packages at runtime
sidesteps the deliberate image composition and silently mutates
whichever container the command runs in. \`pip install --user\`
writes to ~/.local; \`ssh builder pip install --user …\` succeeds
and quietly widens the builder.

If you need a Python tool that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <tool>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for project-local deps: create a venv inside /workspace and
    activate it before installing — the venv is project-scoped and
    travels with the repo.

Read-only inspection is still allowed (\`pip list\`, \`pip show\`,
\`pip freeze\`, \`pipx list\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
