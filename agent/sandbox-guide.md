# Sandbox environment — read this first

You are running inside a hardened sandbox (`claude-agent-sandbox`). The
agent container is intentionally minimal: it has Node, git, curl,
python3, jq, and openssh-client. **It does NOT natively have a JDK,
Maven, Gradle, or any other JVM toolchain.**

A sibling **builder** container (Corretto JDK 25 + Maven 3.9 + Node 22
+ pnpm + Chromium) is reachable over SSH on the internal compose
network. The agent and builder share `/workspace`, so any file you
read or write there is immediately visible to the builder.

## Toolchain wrappers — you usually don't need `ssh builder` explicitly

Common toolchain binaries are *installed in /usr/local/bin as wrappers
that forward to the builder over SSH automatically*. From your point
of view they behave like local commands:

```sh
mvn -v             # runs on the builder, returns Maven 3.9.8
javac --version    # runs on the builder
gradle -v          # runs on the builder
pnpm install       # runs on the builder
```

Wrapped commands: `mvn`, `gradle`, `java`, `javac`, `jar`, `jshell`,
`keytool`, `jdeps`, `jstack`, `jmap`, `jcmd`, `jlink`, `pnpm`.

These wrappers preserve `$PWD` (both containers see /workspace at the
same path), so running `mvn` from `/workspace/module-a` runs `mvn` in
`/workspace/module-a` on the builder. Build-tuning env vars
(`MAVEN_OPTS`, `MAVEN_ARGS`, `GRADLE_OPTS`, `JAVA_OPTS`) are forwarded.

## When to use `ssh builder` explicitly

For anything **not** in the wrapper list above — running raw JDK tools
that aren't symlinked, opening a shell on the builder for debugging,
launching headless Chromium, etc. — go through SSH explicitly:

```sh
ssh builder bash -lc 'cd /workspace && ./gradlew --status'
ssh builder bash -lc 'cd /workspace && chromium --headless --dump-dom https://...'
```

Wrap commands in `bash -lc '…'` when you need shell features like
`cd`, glob expansion, or chained `&&` — bare `ssh builder cmd args`
runs a single binary without a login shell.

Do **not** apt-get / npm install toolchains into the agent — they
belong in the builder image, and the agent rootfs is read-only anyway.

## What the builder has

- JDK 25 (Amazon Corretto) — `JAVA_HOME=/usr/lib/jvm/java-25-amazon-corretto`
- Maven 3.9.8
- Node 22 + pnpm
- Chromium (headless, for browser-driven tests)
- git, curl

The builder runs as a non-root `builder` user (uid 1001). `/workspace`
inside the builder is the same directory as `/workspace` inside the
agent.

## Canonical invocations (use the wrappers, not raw ssh)

```sh
# Java / Maven — wrappers, no `ssh builder` prefix needed
cd /workspace && mvn -B verify
cd /workspace && mvn -B -DskipTests package

# Java / Gradle
cd /workspace && gradle build       # or ./gradlew build

# Node / pnpm
cd /workspace && pnpm install
cd /workspace && pnpm test

# Quick version probes (use sparingly — once per session is plenty)
java -version
mvn -version
```

## Git operations

Run git normally on the agent: `git status`, `git add`, `git commit`,
`git push`, etc. all just work. When a project has
`core.hooksPath=.githooks` with hooks that shell out to `mvn` /
`gradle` / `pnpm`, those calls hit the wrapper, run on the builder,
and the hook succeeds — you don't need to do anything special.

```sh
git status
git add .
git commit -m "..."     # pre-commit hooks calling mvn etc. just work
git push                # pre-push hooks ditto
```

Do **not** reach for `--no-verify` unless the user explicitly asks.
The whole reason the hook exists is to gate bad commits; bypassing it
makes the sandbox less safe than committing on the host would be.

## Testcontainers / Docker-from-builder

The builder has `DOCKER_HOST=tcp://docker-proxy:2375` pre-set. That's a
filtered proxy in front of the host Docker daemon, not the host
daemon directly. Testcontainers (and anything else that respects
`DOCKER_HOST`) will Just Work — spinning up databases, Kafka, redis,
selenium grids, etc. for integration tests.

```sh
# Maven IT phase that uses Testcontainers — runs through the proxy.
ssh builder mvn -f /workspace/pom.xml -B verify
```

What the proxy allows: container CRUD, exec, image pulls, networks,
volumes, events, info, version. What it denies: build, swarm,
secrets, services, nodes, system, plugins, configs, auth.

**Three caveats worth knowing:**

1. **Image pulls bypass the mitmproxy egress filter.** Any image
   Testcontainers asks for is pulled by the *host* daemon over the
   host's network, not through the sandbox's allowlisted proxy. If a
   test pulls a malicious image, the host pulls and runs it. Stick
   to images from trusted registries (`docker.io/library/...`,
   pinned tags) and don't trust arbitrary `latest` tags.
2. **Ryuk (Testcontainers' reaper) is disabled** in this sandbox
   via `TESTCONTAINERS_RYUK_DISABLED=true`. Reason: with
   `DOCKER_HOST=tcp://…` Testcontainers spawns Ryuk on the host's
   default bridge network, where it can't resolve `docker-proxy` —
   the compose-internal DNS doesn't reach there. Cleanup still
   happens on normal JVM exit because Testcontainers spawns its
   containers with `--rm`. Don't try to re-enable Ryuk; if you see
   `Could not find a valid Docker environment` or similar from
   Testcontainers, the fix is somewhere else, not Ryuk.
3. **The proxy does not filter request bodies.** So technically a
   container-create call could include `HostConfig.Binds: ["/:/host"]`
   and the host daemon would honor it. Don't construct such calls
   yourself; you'd be willingly breaking the sandbox. The agent
   should never need to spawn raw `docker` containers — let
   Testcontainers / build tooling do it.

## Network egress

Both the agent and the builder reach the internet only via the
mitmproxy. Maven Central, Gradle plugin portal, npm registry, Sonatype
OSS, and JitPack are already in the default allowlist, so artifact
resolution Just Works. If a build needs an internal repository (Nexus,
Artifactory, internal mirror), it must be added to `ALLOWLIST_EXTRA` on
the proxy — surface that need to the user; don't try to work around it.

## What you should NOT do

- Don't try to install a JDK or build tool into the agent — it will
  fail (read-only rootfs) and would be wrong even if it didn't.
- Don't propose Docker-based workflows (`docker run`, `docker build`)
  from inside the agent — there's no Docker socket, by design.
- Don't say "I can't run tests here" without first trying the builder.
  If `ssh builder …` itself fails, *that* is the real problem to
  report; the builder being the canonical path for toolchain work is
  not a workaround, it is the design.
