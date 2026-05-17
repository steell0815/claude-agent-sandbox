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

| Service        | Role                                                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------------------------- |
| `proxy-init`   | One-shot. Generates the mitmproxy CA into `./ca/` on first run. Idempotent.                                       |
| `proxy`        | `mitmdump` with `proxy/policy.py`. Sole bridge between agent and internet.                                        |
| `keys-init`    | One-shot. Generates the ed25519 keypair the agent uses to SSH into the builder.                                   |
| `builder`      | Long-running JDK 25 + Maven + Node + Chromium sshd. Sibling of the agent, reachable over the internal network.    |
| `docker-proxy` | `tecnativa/docker-socket-proxy` in front of the host Docker daemon. Lets Testcontainers spawn containers, filtered. |
| `agent`        | Claude Code on the internal-only network; no direct egress. Toolchain calls transparently SSH to the builder.     |

Networks:

- `internal` — `internal: true`. Agent ↔ proxy / builder / docker-proxy. No external egress.
- `egress` — bridge. Proxy only.

Hardening rings:

1. **Harness** — host-side `settings.json` allow/deny + `validate-bash` hook (mounted profile from `~/.claude`), plus sandbox-side PreToolUse hooks under `agent/sandbox-hooks/` (block raw `docker` CLI and `apt`/`dpkg` state-changing commands) and toolchain wrappers under `/usr/local/bin` that forcibly route `mvn`/`gradle`/`java`/… to the builder.
2. **Container** — `cap_drop: ALL`, no-new-privileges, read-only rootfs on the agent, non-root users (agent uid 1000, builder uid 1001), tmpfs scratch.
3. **Network** — proxy allowlist + outbound DLP on all agent egress; builder egress likewise.

Each ring is bypassable on its own; together they're meaningful.

## Quickstart

Prereqs: Docker 24+, an Anthropic API key (or pre-authorized `~/.claude`),
~3 GB free disk (agent ~700 MB, builder ~1.6 GB, proxies ~0.3 GB).

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

# 2. Build all images (CA cert now exists for the agent/builder COPY)
docker compose build agent builder keys-init

# 3. Run the agent. The wrapper:
#      - refreshes ~/.claude/.credentials.json from the macOS Keychain
#        (no-op on Linux),
#      - resolves $PWD (or $AGENT_WORKDIR) into the workspace mount,
#      - brings up proxy / keys-init / builder / docker-proxy as needed,
#      - drops you into Claude Code.
#    Extra args are forwarded to `claude`.
./scripts/run-agent.sh

# 4. Tear down (stops the long-running services; volumes preserved)
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

## Harness enforcement

Three layers sit between the LLM and host-level mistakes; only the
first is advisory.

1. **System-prompt guide** (`agent/sandbox-guide.md`). Injected into
   every session via `claude --append-system-prompt`. Tells the
   model where the builder lives, when to use it, and what not to
   do. The LLM can in principle ignore this, so we don't rely on it
   for security — only for ergonomics ("here's the canonical path").
2. **Filesystem wrappers** (`agent/delegate-to-builder` symlinked as
   `/usr/local/bin/{mvn,gradle,java,javac,…,pnpm}`). Real JDK / Maven
   / Gradle binaries don't exist in the agent image, and the rootfs
   is read-only so they can't be installed at runtime. When the LLM
   types `mvn`, it gets the wrapper, which SSHs to the builder. There
   is no path that bypasses this short of writing to a read-only FS.
3. **PreToolUse hooks** (`agent/sandbox-hooks/*.sh` + `agent/sandbox-settings.json`).
   Run by Claude Code *before* the Bash tool executes the command.
   Exit code 2 blocks the call and the rejection message goes back
   to the model as the tool result. Currently shipped:
   - `block-docker-cli.sh` — denies `docker run`/`exec`/`pull`/etc.
   - `block-apt-install.sh` — denies `apt`/`apt-get`/`dpkg` state changes
     (read-only introspection like `apt list`, `dpkg -l` stays allowed).

To add another hook: drop a new script under `agent/sandbox-hooks/`,
list it in `agent/sandbox-settings.json` under the appropriate
matcher, rebuild the agent image. The hook receives the standard
Claude Code hook JSON event on stdin and exits 0 (allow) or 2
(block + stderr message shown to the model).

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

How to use it from inside the sandbox: **toolchain commands work
without an `ssh builder` prefix**. The agent's `/usr/local/bin` ships
wrapper scripts for `mvn`, `gradle`, `java`, `javac`, `jar`, `jshell`,
`keytool`, `jdeps`, `jstack`, `jmap`, `jcmd`, `jlink`, and `pnpm` —
each is a symlink to `agent/delegate-to-builder`, which forwards over
SSH and preserves the current working directory (`/workspace` is the
same path in both containers).

```sh
# From inside the agent (or from a git hook running inside the agent):
cd /workspace && mvn -B verify         # runs on the builder
cd /workspace && gradle build          # runs on the builder
cd /workspace && pnpm install          # runs on the builder
java -version                          # runs on the builder
```

For non-wrapped tools — opening a shell on the builder for debugging,
running headless Chromium, invoking less-common JDK binaries — use
`ssh builder` directly:

```sh
ssh builder bash -lc 'cd /workspace && ./gradlew --status'
ssh builder bash -lc 'chromium --headless --dump-dom https://example.com'
```

The `cas` wrapper runs `docker compose up -d builder` before
launching the agent, so the builder is always reconciled with the
current `$AGENT_WORKDIR`. Switching `cas` between projects can't
leave the builder pinned to a stale workspace.

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
| `CAS_HOME`             | (auto-resolved)    | Override for `run-agent.sh`'s repo lookup. Set when the wrapper is copied (not symlinked) onto `$PATH`. See "Install once, run from anywhere" above. |

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

Claude Code control plane:

- `^api\.anthropic\.com$`
- `^statsig\.anthropic\.com$`
- `^platform\.claude\.com$` (console / OAuth surface used by Claude Code at startup)

Build-toolchain artifact hosts (used by the builder):

- `^repo\.maven\.apache\.org$`, `^repo1\.maven\.org$` — Maven Central
- `^services\.gradle\.org$`, `^downloads\.gradle\.org$`, `^plugins\.gradle\.org$`, `^plugins-artifacts\.gradle\.org$` — Gradle distributions + plugin portal
- `^registry\.npmjs\.org$` — npm / pnpm registry
- `^oss\.sonatype\.org$`, `^s01\.oss\.sonatype\.org$` — Sonatype OSS
- `^jitpack\.io$` — JitPack

For internal repos (Nexus, Artifactory, internal mirrors), add them
via `ALLOWLIST_EXTRA` — see the **Builder** section above.

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
# Cover both repo scripts and image-baked-in ones.
bash -n proxy/bootstrap-ca.sh agent/entrypoint.sh builder/entrypoint.sh \
        agent/delegate-to-builder agent/sandbox-hooks/*.sh \
        keys-init/init.sh scripts/run-agent.sh scripts/export-keychain-credentials.sh
python3 -m py_compile proxy/policy.py

# Policy unit tests (require mitmproxy + pytest). Easiest inside the
# proxy image, which already has mitmproxy installed:
docker run --rm -v "$PWD/proxy:/work" -w /work --entrypoint sh \
  claude-agent-sandbox-proxy -c \
  'pip install pytest --quiet --user && python -m pytest tests/test_policy.py -q'

# Compose validation
docker compose config -q

# Hadolint on the four Dockerfiles
for f in agent/Dockerfile builder/Dockerfile keys-init/Dockerfile proxy/Dockerfile; do
  docker run --rm -i hadolint/hadolint < "$f"
done
```

CI runs the same checks plus `sast.yml` (Semgrep, ShellCheck, Hadolint, Trivy)
and `git-integrity.yml` (`git fsck`).

## Known limitations

- **Cert pinning** — Go binaries with embedded roots, `gcloud`, mobile SDKs
  fail under MITM. `npm`, `pip`, `cargo`, `git`, `curl`, `gh`, the Anthropic
  SDK, Claude Code, and Maven/Gradle (the JVM `cacerts` truststore has the
  mitm CA imported at builder image build time) all honor the trust store
  and work.
- **SSE granularity** — Anthropic's API uses SSE; the request hook fires at
  request time, the response hook fires when the stream closes. Per-chunk
  audit needs `responseheaders` + `response_chunk` hooks (not implemented).
- **CA private key** — anyone with `./ca/mitmproxy-ca.pem` (cert + key) can
  forge any cert the agent trusts. Generated per-deployment, never committed,
  never mounted to the agent.
- **Memory persistence** — `~/.claude/projects/<x>/memory/` lands on tmpfs
  and is lost on container restart. `~/.claude.json` is persisted via the
  `sandbox-state` named volume (so theme / trusted-directory / project
  history survive), but per-project memory needs a separate compose-override
  named volume.
- **Token refresh on a read-only mount** — Claude Code rotates its OAuth
  access token and tries to write the new value back to `.credentials.json`,
  but `~/.claude` is mounted read-only. `scripts/run-agent.sh` mitigates
  this by re-exporting from the macOS Keychain on every `cas` invocation,
  so each session starts with a fresh credential. In-session refresh is
  still a no-op; long-running interactive sessions may need re-invocation.
- **Testcontainers image pulls bypass the egress allowlist.** Images pulled
  by the host daemon on Testcontainers' behalf don't traverse the mitmproxy.
  Pin to trusted registries; see the **Testcontainers** section above.
- **Builder cache volume ownership** — `builder-m2` / `builder-gradle-cache`
  volumes created before commit `779586a` are owned by `root:root`. With
  `cap_drop: ALL`, even uid 0 in the builder can't write into them. Symptom:
  `mvn` failing with `Permission denied` against `~/.m2/repository`. Fix:
  ```sh
  docker run --rm \
    -v claude-agent-sandbox_builder-m2:/m2 \
    -v claude-agent-sandbox_builder-gradle-cache:/gradle \
    alpine chown -R 1001:1001 /m2 /gradle
  ```
  Or wipe and let them be reborn:
  `docker volume rm claude-agent-sandbox_builder-m2 claude-agent-sandbox_builder-gradle-cache`.

## Layout

```
.
├── docker-compose.yml          # 6 services: proxy-init, proxy, keys-init, builder, docker-proxy, agent
├── .env.example                # config knobs
├── proxy/
│   ├── Dockerfile              # mitmproxy + policy.py
│   ├── policy.py               # allowlist + DLP + audit
│   ├── bootstrap-ca.sh         # CA generator (proxy-init)
│   └── tests/                  # pytest unit tests for policy
├── agent/
│   ├── Dockerfile              # agent image
│   ├── entrypoint.sh           # cred validation, --append-system-prompt, --settings
│   ├── ssh-config              # baked-in ~/.ssh/config for `Host builder`
│   ├── delegate-to-builder     # toolchain wrapper (mvn/gradle/java/... symlink to this)
│   ├── sandbox-guide.md        # injected into the system prompt every session
│   ├── sandbox-settings.json   # claude --settings; wires up PreToolUse hooks
│   └── sandbox-hooks/          # PreToolUse hook scripts (block-docker-cli, block-apt-install)
├── builder/
│   ├── Dockerfile              # JDK 25 + Maven + Node + Chromium + sshd
│   ├── entrypoint.sh           # host-key gen, install authorized_keys, exec sshd
│   ├── sshd_config             # pubkey-only, port 2222, AcceptEnv MAVEN_OPTS/...
│   ├── maven-settings.xml      # routes Maven resolution through the mitmproxy
│   ├── gradle.properties       # same for Gradle
│   └── allowlist.txt           # reference list of artifact-host regexes
├── keys-init/
│   ├── Dockerfile              # alpine + ssh-keygen
│   └── init.sh                 # idempotent ed25519 keypair generator
├── scripts/
│   ├── run-agent.sh            # the `cas` wrapper
│   ├── export-keychain-credentials.sh
│   └── hooks/                  # this repo's own pre-commit / commit-msg gates
├── ca/                         # generated by proxy-init; mitmproxy CA lives here
├── project/                    # default bind-mount target for /workspace
├── plans/                      # design plan(s)
└── .github/workflows/          # ci.yml (compose+pytest), sast/dast/git-integrity
```

## License

MIT — see [LICENSE](./LICENSE).
