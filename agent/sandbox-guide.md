# Sandbox environment — read this first

You are running inside a hardened sandbox (`claude-agent-sandbox`). The
agent container is intentionally minimal: it has Node, git, curl,
python3, jq, and openssh-client. **It does NOT have a JDK, Maven,
Gradle, or any other JVM toolchain.**

For toolchain work, there is a sibling **builder** container reachable
over SSH on the internal compose network. The agent and builder share
`/workspace` (bind-mounted from the same host directory), so any file
the agent reads or writes there is immediately visible to the builder
and vice-versa.

## When to use the builder

Use `ssh builder …` whenever a task needs the JVM, Maven, Gradle, Node
runtime for build/test (not script execution), Chromium, or any other
toolchain not in the agent's PATH. Do **not** apt-get / npm install
toolchains into the agent — they belong in the builder image, and the
agent rootfs is read-only anyway.

## What the builder has

- JDK 25 (Amazon Corretto) — `JAVA_HOME=/usr/lib/jvm/java-25-amazon-corretto`
- Maven 3.9.8
- Node 22 + pnpm
- Chromium (headless, for browser-driven tests)
- git, curl

The builder runs as a non-root `builder` user (uid 1001). `/workspace`
inside the builder is the same directory as `/workspace` inside the
agent.

## Canonical invocations

```sh
# Java / Maven
ssh builder mvn -f /workspace/pom.xml -B verify
ssh builder mvn -f /workspace/pom.xml -B -DskipTests package

# Java / Gradle
ssh builder bash -lc 'cd /workspace && ./gradlew build'

# Node / pnpm
ssh builder bash -lc 'cd /workspace && pnpm install'
ssh builder bash -lc 'cd /workspace && pnpm test'

# Quick version probes (use sparingly — once per session is plenty)
ssh builder java -version
ssh builder mvn -version
```

Wrap commands in `bash -lc '…'` when you need shell features like `cd`,
glob expansion, or chained `&&` — bare `ssh builder cmd args` runs a
single binary without a login shell.

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
