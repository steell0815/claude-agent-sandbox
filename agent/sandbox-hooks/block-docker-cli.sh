#!/usr/bin/env bash
# PreToolUse hook for Bash: deny `docker` CLI invocations.
#
# Threat model: the LLM might reach for `docker run` / `docker exec` /
# etc. to spawn or poke at containers directly, sidestepping the
# Testcontainers + docker-proxy pipeline the sandbox is built around.
# We don't filter the Docker API at the request level (tecnativa proxy
# can't), so a stray `docker run -v /:/host ...` from inside the
# builder is a real escape path. Blocking the CLI at the tool-call
# layer closes that off cheaply.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# Match `docker` as a separate token followed (within a short window) by
# a sub-command we care about. Anchors on common shell prefixes/separators
# so `sudo docker run`, `&& docker exec`, `env X=y docker rm`, etc. all
# match. Covers ~95% of real cases; `docker -H other-daemon run` slips
# through but the user can extend this regex if it bites.
deny_re='(^|[[:space:];|&(])docker[[:space:]]+(run|exec|rm|rmi|start|stop|restart|kill|cp|build|commit|create|pull|push|save|load|tag|attach|wait|update|rename|export|import)([[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$deny_re"; then
  cat >&2 <<EOF
[sandbox] blocked: raw docker CLI invocations are not allowed.

This sandbox routes Docker access through a filtered proxy
(\`docker-proxy:2375\`) that is consumed by Testcontainers and other
build tooling automatically. There is no use case in normal operation
where the agent should shell out to \`docker\` directly.

If you were trying to:
  - run integration tests          -> \`cd /workspace && mvn -B verify\`
  - spawn a Postgres/Kafka/etc.    -> let Testcontainers do it
  - inspect what's running         -> ask the operator; this sandbox
                                       intentionally hides the host's
                                       daemon from the agent.

If you genuinely need to bypass this rule for the current task, ask
the user to remove or relax the hook in agent/sandbox-settings.json.

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
