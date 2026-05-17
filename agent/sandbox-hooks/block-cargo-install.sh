#!/usr/bin/env bash
# PreToolUse hook for Bash: deny `cargo install` / `cargo uninstall`.
#
# Threat: same as the apt, node, and pip hooks — `cargo install` writes
# a binary to ~/.cargo/bin (or $CARGO_HOME), extending the runtime image
# outside its Dockerfile. The agent's read-only rootfs blocks it locally,
# but `ssh builder cargo install …` would silently succeed.
#
# Only `install` and `uninstall` are blocked. Project-scoped operations
# (`cargo build`, `cargo run`, `cargo test`, `cargo check`, `cargo fmt`,
# `cargo clippy`, `cargo doc`, `cargo new`, `cargo init`, `cargo
# metadata`, `cargo tree`, `cargo search`, `cargo audit`, etc.) all stay
# allowed.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

CARGO_RE='(^|[[:space:];|&(])cargo[[:space:]]+(install|uninstall)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$CARGO_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: \`cargo install\` / \`cargo uninstall\` is not allowed.

\`cargo install\` writes a binary to ~/.cargo/bin, extending the
runtime image outside its Dockerfile. Same story as npm install -g,
pip install, apt-get install. The agent rootfs is read-only so it
fails here; \`ssh builder cargo install …\` would succeed and
quietly widen the builder.

If you need a Rust binary that isn't there:
  - check if it's already in the builder  -> \`ssh builder which <bin>\`
  - if it's missing, ask the user to add it to builder/Dockerfile and
    rebuild (\`docker compose build builder\`).
  - for in-project builds, \`cargo build\` / \`cargo run\` write to
    ./target which is in /workspace and travels with the repo — that
    stays allowed.

Read-only / project-scoped operations are still allowed
(\`cargo build\`, \`run\`, \`test\`, \`check\`, \`fmt\`, \`clippy\`,
\`new\`, \`init\`, \`tree\`, \`search\`, \`metadata\`, etc.).

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
