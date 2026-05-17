#!/usr/bin/env bash
# PreToolUse hook for Bash: deny "fetch a remote script and pipe it
# straight into a shell" patterns.
#
# Threat: the classic install-script footgun — `curl https://… | sh`
# runs whatever bytes the server hands back, with no review, no audit,
# no cache, no version pin. The proxy allowlist limits *who* can serve
# such a script, but doesn't validate its content. Once the bytes
# reach a shell process inside the builder, the script can do anything
# the builder user can do — install tools, modify the build cache,
# exfiltrate via the egress proxy, etc. Same threat shape as the other
# install hooks, expressed via remote code execution rather than a
# package manager.
#
# Coverage:
#   - curl <url> | sh           (also bash, zsh, ksh, dash, sudo bash)
#   - wget <args> | sh          (-O- / -O - / piped stdout)
#   - fetch <url> | sh          (BSD)
#   - curl <url> | python -     (also python3; `-` means "read stdin")
#                               — covers the Poetry / Rustup-style
#                               install bootstrap pipelines.
#   - bash <(curl <url>)        (process substitution; also zsh, ksh)
#   - bash -c "$(curl <url>)"   (command-substitution form)
#   - python -c "$(curl <url>)" (also python3)
#   - eval "$(curl <url>)"      (eval-from-fetch)
#
# Not covered (out of scope for a regex hook):
#   - downloading a file then executing it as a separate step. That's
#     two tool calls and the operator has a chance to see the
#     downloaded content before running it.
#   - Less common interpreters (ruby/perl/php with `-`) — easy to
#     add to the patterns below if it becomes a real concern.
#
# Protocol: receives a JSON event on stdin
#   { "tool_name": "Bash", "tool_input": { "command": "...", ... }, ... }
# Exit 0 -> allow.  Exit 2 -> block (stderr is shown to the model).

set -euo pipefail

event=$(cat)
cmd=$(printf '%s' "$event" | jq -r '.tool_input.command // ""')

# `curl|wget|fetch <args>* | <shell>` — pipe-to-shell, any args after sh.
# Match shell at the right side of the pipe (with optional `sudo ` prefix).
PIPE_SHELL_RE='(curl|wget|fetch)[[:space:]]+[^|;&()]*\|[[:space:]]*(sudo[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)?(sh|bash|zsh|ksh|dash)([[:space:]]|$|[;|&])'

# `curl|wget|fetch <args>* | python[3] -` — interpreter reading stdin.
# Requires `-` as a complete token so that `… | python3 script.py` (where
# stdin is data for the script, not code to execute) doesn't false-match.
PIPE_INTERP_RE='(curl|wget|fetch)[[:space:]]+[^|;&()]*\|[[:space:]]*(sudo[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)?(python|python3)[[:space:]]+-([[:space:]]|$|[;|&])'

# `<shell> <(curl …)` — process substitution. Only bash/zsh/ksh do this.
PROCSUB_RE='(^|[[:space:];|&(])(bash|zsh|ksh)[[:space:]]+<\([[:space:]]*(curl|wget|fetch)[[:space:]]'

# `<shell> -c "$(curl …)"` / `eval "$(curl …)"` — command substitution
# fed into a shell, eval, or python.
CMDSUB_RE='(eval|(sh|bash|zsh|ksh|dash|python|python3)[[:space:]]+-c)[[:space:]]+["\x27]?\$\([[:space:]]*(curl|wget|fetch)[[:space:]]'

if printf '%s' "$cmd" | grep -qE "$PIPE_SHELL_RE|$PIPE_INTERP_RE|$PROCSUB_RE|$CMDSUB_RE"; then
  cat >&2 <<EOF
[sandbox] blocked: piping a remote fetch into a shell is not allowed.

This refuses patterns like:
  curl <url> | sh                # the classic install-script footgun
  curl <url> | bash
  wget -O- <url> | sh
  bash <(curl <url>)             # process substitution
  bash -c "\$(curl <url>)"       # command substitution
  eval "\$(curl <url>)"

The threat: the server hands back arbitrary bytes that a shell
process inside the sandbox then executes. The proxy allowlist
controls *who* can serve such a script, but doesn't validate the
script's content. Once executed, it can install tools, mutate the
build cache, or trigger any of the other install paths — every hook
in this sandbox exists to keep that from happening.

Safer paths for the common cases:
  - need a CLI tool?               -> add it to builder/Dockerfile and
                                      rebuild (\`docker compose build builder\`).
  - need a one-shot script run?    -> \`curl -o script.sh <url> &&
                                      review script.sh && bash script.sh\`
                                      (two steps, with the operator's
                                      eyes on the bytes in between).
  - need a pinned bootstrap?       -> bake the script + checksum into
                                      builder/Dockerfile so the
                                      version is reviewable.

Refused command:
  $cmd
EOF
  exit 2
fi

exit 0
