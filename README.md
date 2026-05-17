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

1. **Harness** — `settings.json` allow/deny + `validate-bash` hook (mounted profile), plus a PreToolUse `Bash` hook that blocks raw `docker` CLI invocations (`agent/sandbox-hooks/block-docker-cli.sh`).
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

# 3. Start the proxy in the background and run the agent interactively.
#    The wrapper refreshes ~/.claude/.credentials.json from the macOS
#    Keychain on each run (no-op on Linux), then `docker compose run`s
#    the agent. Args after the script are forwarded to `claude`.
docker compose up -d proxy
./scripts/run-agent.sh  # drops you into Claude Code

# 4. Tear down
docker compose down
```

> **macOS detail.** Claude Code stores its credential in the Keychain by
> default, not as a file on disk, so the read-only `~/.claude` bind-mount
> alone won't carry it into the container. `scripts/export-keychain-credentials.sh`
> reads `Claude Code-credentials` from the Keychain, validates it parses
> as JSON, and writes it atomically to `~/.claude/.credentials.json` with
> `0600` perms. `./scripts/run-agent.sh` calls it for you on every run, so
> you only need to invoke the exporter directly when scripting around
> `docker compose run --rm agent` yourself.

The agent's working directory is `./project/` (bind-mounted at `/workspace`)
by default. To attach the sandbox to any other project — a Java repo, a
playground checkout, anything — point it at that directory instead.

### Attach the sandbox to an arbitrary directory

`scripts/run-agent.sh` resolves which host path to mount at `/workspace`
in this order:

1. `AGENT_WORKDIR` (absolute path) if set.
2. `$PWD` when the script is invoked from outside this repo.
3. `./project/` when invoked from the repo root (preserves the quickstart).

So the common case is "cd to the project, run the wrapper".

**Install once, run from anywhere.** Two install patterns:

```sh
# (a) Symlink — wrapper finds the repo by walking back from its own path.
ln -s "$PWD/scripts/run-agent.sh" ~/.local/bin/cas

# (b) Copy + env var — wrapper uses $CAS_HOME to locate the repo.
#     Handy if you keep multiple checkouts or pull the script via dotfiles.
cp scripts/run-agent.sh ~/.local/bin/cas
echo 'export CAS_HOME=~/dev/claude-agent-sandbox' >> ~/.zshrc
```

Then, from any project:

```sh
cd ~/code/my-java-service
cas                          # mounts $PWD at /workspace
cas -p "audit the pom.xml"   # extra args forwarded to `claude`

# Or pin the workdir explicitly (handy from CI):
AGENT_WORKDIR=/abs/path/to/project cas
```

Notes:

- The path must be one Docker Desktop is allowed to share (anything under
  `$HOME` is by default on macOS).
- All projects share the same `sandbox-state` volume and proxy. If you want
  per-project state (`~/.claude.json`, history), set
  `COMPOSE_PROJECT_NAME=cas-myproj` before invoking the wrapper to get a
  distinct stack name and isolated volumes.
- The agent runs as uid 1000. On macOS this is transparent; on Linux,
  files you create from inside the sandbox will be owned by uid 1000 on
  the host.

## Builder (Java / Node toolchain)

The agent image is intentionally minimal — Node + git + curl + python3 +
jq, no JDK or Maven. To build/test JVM or Node projects from inside the
sandbox there's a sibling **builder** service: a long-running container
with Corretto JDK 25, Maven 3.9, Node 22, pnpm, git, and headless Chrome.
The agent reaches it over SSH on the internal compose network — same
mental model as a Jenkins SSH agent, without giving the LLM access to
the host Docker socket.

```text
+---------+    ssh:2222     +-----------+    HTTPS via proxy    +---------------+
|  agent  |  ------------>  |  builder  |  ------------------>  | Maven Central |
+---------+                 +-----------+                       +---------------+
       \                         /
        \                       /
         +-- /workspace (rw) --+    same host dir bind-mounted into both
```

How to use it from inside the sandbox:

```sh
ssh builder mvn -f /workspace/pom.xml -B verify
ssh builder ./gradlew -p /workspace build
ssh builder pnpm --dir /workspace install
```

Artifact hosts (Maven Central, Gradle, npm, Sonatype OSS, JitPack) are in
the proxy's default allowlist — no extra config needed for those. For
**internal repositories** (Nexus, Artifactory, internal mirrors) add them
via `ALLOWLIST_EXTRA`:

```sh
# In .env:
ALLOWLIST_EXTRA=/etc/proxy/builder-allowlist.txt
```

…and mount your extra-allowlist file into the proxy via an overlay:

```yaml
# docker-compose.override.yml
services:
  proxy:
    volumes:
      - ./my-internal-allowlist.txt:/etc/proxy/builder-allowlist.txt:ro
```

`builder/allowlist.txt` in the repo lists the artifact hosts already in
the default; use it as a reference for what regexes look like.

Notes:

- **SSH key.** Generated once by the `keys-init` one-shot into the
  `builder-keys` named volume on first `docker compose up`. Wipe and
  regenerate with `docker volume rm <project>_builder-keys`.
- **Truststore.** The mitmproxy CA is imported into the JVM's `cacerts`
  at builder image build time, so Maven/Gradle TLS to Maven Central
  through the proxy succeeds without `-Dtrust=all` hacks.
- **Caches.** `~/.m2/repository` and `~/.gradle/caches` inside the
  builder are backed by named volumes (`builder-m2`, `builder-gradle-cache`)
  and persist across runs.
- **Re-vendoring.** `builder/Dockerfile` is a vendored copy of
  `bks-digital-sales/docker/mvnj25chromium/docker/dockerfile` plus
  sandbox-specific additions (sshd, builder user, CA into truststore).
  Re-sync when the upstream image changes; the header comment lists the
  diff so it's easy to re-apply.
- **Docker access.** The agent has no `/var/run/docker.sock`. The
  builder talks to a `docker-proxy` (tecnativa/docker-socket-proxy)
  on the internal network — see the **Testcontainers** section below.

### Testcontainers

The builder sets `DOCKER_HOST=tcp://docker-proxy:2375`, where
`docker-proxy` is a `tecnativa/docker-socket-proxy` filtering the
host Docker daemon. Testcontainers picks up `DOCKER_HOST`
automatically: `mvn verify` with Testcontainers-backed integration
tests works inside the sandbox.

What the proxy allows: container CRUD, exec, image pulls, networks,
volumes, info, version, events. What it denies: build, swarm,
secrets, services, nodes, system, plugins, configs, auth.

**Security tradeoffs to be deliberate about:**

- The Ryuk reaper container Testcontainers spawns needs to bind-mount
  `/var/run/docker.sock` into itself. We allow that — and consequently
  the proxy doesn't (and can't, with tecnativa) filter individual
  `HostConfig.Binds` entries. A client that can reach `2375` can
  request any bind mount; in this sandbox that client is the builder,
  and via `ssh builder docker …` effectively the LLM. Treat
  `docker-proxy:2375` as a privileged surface and judge accordingly.
- Image pulls happen on the *host* daemon, not through `mitmproxy`.
  Whatever your tests pull comes down the host's network without the
  sandbox's allowlist applied. Pin Testcontainers images to trusted
  registries (`docker.io/library/...`, hashed/tagged versions); don't
  trust arbitrary `latest` from unknown publishers.
- If you want a tighter wedge (allow Ryuk's socket bind but deny all
  other binds), `wollomatic/socket-proxy` does per-field regex
  filtering. Drop-in upgrade from tecnativa.

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
| `BUILDER_MEM_LIMIT`    | `6g`               | Builder container memory cap (JVM + Gradle daemons).     |
| `BUILDER_CPUS`         | `4`                | Builder container CPU cap.                               |
| `AGENT_WORKDIR`        | `./project`        | Host path bind-mounted at `/workspace` in agent+builder. |

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
- `^platform\.claude\.com$` (console / OAuth surface used by Claude Code at startup)

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
