# claude-agent-sandbox

Docker-based sandbox for AI agents (Claude Code by default). The agent runs
inside a hardened container with **no direct network**: every outbound HTTP(S)
flow is forced through a `mitmdump`-based proxy that enforces a host allowlist
and runs body-side DLP regexes. The proxy's CA is baked into the agent image
at build time so the agent transparently trusts the MITM, while the CA private
key never reaches the agent container.

The repo is the **execution environment + verification gates** for the sandbox
itself. Agent profile (Claude Code settings, skills, hooks, guardrails) is
mounted in from `~/.claude` on the host — that material is owned elsewhere and
is intentionally **not** maintained in this repo.

## Architecture at a glance

| Service      | Role                                                                        |
| ------------ | --------------------------------------------------------------------------- |
| `proxy-init` | One-shot. Generates the mitmproxy CA into `./ca/` on first run. Idempotent. |
| `proxy`      | `mitmdump` with `proxy/policy.py`. Sole bridge between agent and internet.  |
| `agent`      | Claude Code on a network-internal-only bridge; no direct egress.            |

Networks:

- `internal` — `internal: true`. Agent ↔ proxy only. No external egress.
- `egress` — bridge. Proxy only.

Hardening rings:

1. **Harness** — `settings.json` allow/deny + `validate-bash` hook (mounted profile).
2. **Container** — `cap_drop: ALL`, no-new-privileges, read-only rootfs, non-root user, tmpfs scratch.
3. **Network** — proxy allowlist + outbound DLP.

Each ring is bypassable on its own; together they're meaningful.

## Quickstart

Prereqs: Docker 24+, an Anthropic API key (or pre-authorized `~/.claude`),
~500 MB free disk for the agent image.

```sh
# 0. Auth — pick one:
#    a) Headless / API-billed: drop your key into .env
echo "ANTHROPIC_API_KEY=sk-ant-..." > .env
#    b) macOS host with `claude login` already done: export the credential
#       from the Keychain to a file the sandbox can mount.
./scripts/export-keychain-credentials.sh
#    c) Linux host: ~/.claude/.credentials.json already exists, nothing to do.

# 1. Generate the proxy CA into ./ca/ (one-time, idempotent)
docker compose run --rm proxy-init

# 2. Build the agent image (now that the CA cert exists for the COPY)
docker compose build agent

# 3. Start the proxy in the background and run the agent interactively
docker compose up -d proxy
docker compose run --rm agent  # drops you into Claude Code

# 4. Tear down
docker compose down
```

> **macOS detail.** Claude Code stores its credential in the Keychain by
> default, not as a file on disk, so the read-only `~/.claude` bind-mount
> alone won't carry it into the container. `scripts/export-keychain-credentials.sh`
> reads `Claude Code-credentials` from the Keychain, validates it parses
> as JSON, and writes it atomically to `~/.claude/.credentials.json` with
> `0600` perms. Re-run it whenever the host token rotates.

The agent's working directory is `./project/` (bind-mounted at `/workspace`).
Drop the source you want the agent to work on there — or replace the bind
target with the project you want to attach to.

## Configuration

Copy `.env.example` → `.env` and uncomment knobs as needed. Common ones:

| Variable               | Default            | Purpose                                                  |
| ---------------------- | ------------------ | -------------------------------------------------------- |
| `ANTHROPIC_API_KEY`    | (unset)            | Headless auth. Falls back to `.credentials.json` mount.  |
| `CLAUDE_CODE_VERSION`  | `latest`           | npm tag for `@anthropic-ai/claude-code`.                 |
| `ALLOWLIST_EXTRA`      | (unset)            | Path *inside the proxy* to a file with extra host regexes. |
| `DLP_EXTRA`            | (unset)            | Path *inside the proxy* to a file with extra DLP regexes.  |
| `AUDIT_MAX_BYTES`      | `52428800`         | Audit log rotation size (50 MiB).                        |
| `AUDIT_BACKUPS`        | `10`               | Rotated audit files kept (×50 MiB ≈ 500 MiB ceiling).    |
| `AGENT_MEM_LIMIT`      | `4g`               | Agent container memory cap.                              |
| `AGENT_CPUS`           | `2`                | Agent container CPU cap.                                 |

To pass a project-specific allowlist, mount it onto the proxy and point the
env var at it. Example overlay (`docker-compose.override.yml`):

```yaml
services:
  proxy:
    volumes:
      - ./.devcontainer/allowlist.txt:/etc/proxy/allowlist.txt:ro
    environment:
      ALLOWLIST_EXTRA: /etc/proxy/allowlist.txt
```

## Default policy

Allowlist (regexes, anchored — extend via `ALLOWLIST_EXTRA`):

- `^api\.anthropic\.com$`
- `^statsig\.anthropic\.com$`

DLP (matched against request bodies — extend via `DLP_EXTRA`):

- AWS access key IDs (`AKIA...`)
- PEM private-key blocks
- GitHub/GitLab personal access tokens
- JWT-shaped tokens

DLP is best-effort. It catches common accidental leaks; it is not a defense
against an actively malicious agent.

## Audit log

Two streams:

- **Container stdout/stderr** — Docker `local` driver, 10 MiB × 5 = ~50 MiB per service.
- **Application audit** — `/var/log/proxy/audit.jsonl` inside the named `logs`
  volume. Rotated by `RotatingFileHandler` in `policy.py`. The agent gets a
  read-only view at the same path for self-debugging.

Each line is a single JSON object: `{ts, host, method, path, allowed, reason, size}`.

## Development

```sh
# Pre-commit gate (bash syntax + secret detection) runs automatically.
bash -n proxy/bootstrap-ca.sh agent/entrypoint.sh
python3 -m py_compile proxy/policy.py

# Policy unit tests (requires mitmproxy + pytest)
pip install "mitmproxy~=11.0" pytest
pytest proxy/tests/ -v

# Compose validation
docker compose config -q
```

CI runs the same checks plus `sast.yml` (Semgrep, ShellCheck, Hadolint, Trivy)
and `git-integrity.yml` (`git fsck`).

## Known limitations

- **Cert pinning** — Go binaries with embedded roots, `gcloud`, mobile SDKs
  fail under MITM. `npm`, `pip`, `cargo`, `git`, `curl`, `gh`, the Anthropic
  SDK, and Claude Code all honor the system trust store and work.
- **SSE granularity** — Anthropic's API uses SSE; the request hook fires at
  request time, the response hook fires when the stream closes. Per-chunk
  audit needs `responseheaders` + `response_chunk` hooks (not in Phase 1).
- **CA private key** — anyone with `./ca/mitmproxy-ca.pem` (cert + key) can
  forge any cert the agent trusts. Generated per-deployment, never committed,
  never mounted to the agent.
- **Memory persistence** — `~/.claude/projects/<x>/memory/` lands on tmpfs in
  Phase 1 and is lost on container restart. To persist, add a named volume
  for that subpath in a compose override.
- **Read-only mount blocks token refresh** — Claude Code rotates its OAuth
  access token periodically and tries to write the new value back to
  `.credentials.json`. The read-only mount makes that a no-op; in practice
  the in-memory token survives the session, but multi-day containers may
  need a restart to pick up a freshly-refreshed host token.

## Layout

```
.
├── docker-compose.yml          # 3-service stack (proxy-init, proxy, agent)
├── .env.example                # config knobs
├── proxy/
│   ├── Dockerfile              # mitmproxy + policy.py
│   ├── policy.py               # allowlist + DLP + audit
│   ├── bootstrap-ca.sh         # CA generator (proxy-init)
│   └── tests/                  # pytest unit tests for policy
├── agent/
│   ├── Dockerfile              # multi-stage (agent-base, agent)
│   └── entrypoint.sh
├── project/                    # bind-mounted to /workspace (default target)
├── plans/                      # design plan(s)
├── scripts/hooks/              # pre-commit + commit-msg gates
└── .github/workflows/          # ci.yml (compose+pytest), sast/dast/git-integrity
```

## License

MIT — see [LICENSE](./LICENSE).
