# builder image — JDK 25 + Maven + Node + Chromium, exposed to the agent
# over SSH on an isolated compose network.
#
# Vendored from bks-digital-sales/docker/mvnj25chromium/docker/dockerfile.
# Differences vs. the source:
#   - removed the chrome `ENTRYPOINT` (we run sshd as PID 1 instead;
#     chrome is still installed and can be launched on demand for tests)
#   - removed the `mvn-entrypoint.sh` ENTRYPOINT for the same reason
#   - added openssh-server + a non-root `builder` user
#   - imported the mitmproxy CA into the JVM truststore so Maven/Gradle TLS
#     to repo1.maven.org etc. succeeds through the egress proxy
#   - sshd listens on 2222 so the daemon never needs CAP_NET_BIND_SERVICE
#
# Re-sync from the source dockerfile whenever the upstream image changes.

FROM debian:stable-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG CA_CERT_PATH=ca/mitmproxy-ca-cert.pem

# ---------------------------------------------------------------------------
# Source-image layers (kept close to the original for easy re-vendor diffs).
# ---------------------------------------------------------------------------

# hadolint ignore=DL3008
RUN apt-get update -qqy \
 && apt-get -qqy install --no-install-recommends \
      dumb-init gnupg wget ca-certificates apt-transport-https \
      ttf-wqy-zenhei \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Chromium (kept available for headless browser tests; not the entrypoint).
# Source-image diff: uses Debian's `chromium` package instead of Google's
# `google-chrome-unstable`. Reason: google-chrome-unstable is amd64-only,
# so the sandbox would fail to build on Apple Silicon and other ARM hosts.
# Debian's `chromium` is multi-arch and serves the same use case.
# hadolint ignore=DL3008
RUN apt-get update -qqy \
 && apt-get -qqy install --no-install-recommends libxml2-utils chromium \
 && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# JDK 25 (Corretto), Node 22, pnpm, git, openssh-client.
# Bump PNPM_VERSION as needed; hadolint DL3016 requires npm pins.
ARG PNPM_VERSION=11.1.2
# hadolint ignore=DL3008,DL4006
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg openssh-client \
 && GNUPGHOME="$(mktemp -d)" \
 && export GNUPGHOME \
 && curl -fL https://apt.corretto.aws/corretto.key | gpg --batch --import \
 && gpg --batch --export '6DC3636DAE534049C8B94623A122542AB04F24E3' > /usr/share/keyrings/corretto.gpg \
 && unset GNUPGHOME \
 && echo "deb [signed-by=/usr/share/keyrings/corretto.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends java-25-amazon-corretto-jdk git \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g "pnpm@${PNPM_VERSION}" \
 && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME="/usr/lib/jvm/java-25-amazon-corretto"

# Maven (copied from the official Maven 3.9.8 image — same trick the source uses).
ENV MAVEN_HOME=/usr/share/maven
COPY --from=maven:3.9.8-eclipse-temurin-11 ${MAVEN_HOME} ${MAVEN_HOME}
COPY --from=maven:3.9.8-eclipse-temurin-11 /usr/local/bin/mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
COPY --from=maven:3.9.8-eclipse-temurin-11 /usr/share/maven/ref/settings-docker.xml /usr/share/maven/ref/settings-docker.xml
RUN ln -s ${MAVEN_HOME}/bin/mvn /usr/bin/mvn

# ---------------------------------------------------------------------------
# Sandbox-specific additions: mitm CA, sshd, builder user.
# ---------------------------------------------------------------------------

# OS trust store: every TLS client (curl, git, npm) sees the proxy as legit.
# JVM trust store (cacerts): Maven/Gradle don't read the OS bundle, so we
# also import the CA explicitly with keytool — same RUN to keep the trust
# install atomic and silence DL3059.
COPY ${CA_CERT_PATH} /usr/local/share/ca-certificates/mitm.crt
RUN update-ca-certificates \
 && keytool -importcert -noprompt -trustcacerts \
      -alias mitmproxy-ca \
      -file /usr/local/share/ca-certificates/mitm.crt \
      -cacerts -storepass changeit

# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server tini \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/run/sshd

# Non-root user that owns workspace + caches and accepts SSH sessions.
RUN groupadd --gid 1001 builder \
 && useradd --create-home --uid 1001 --gid 1001 --shell /bin/bash builder \
 && install -d -o builder -g builder -m 0700 /home/builder/.ssh \
 && install -d -o builder -g builder -m 0755 /home/builder/.m2 \
 && install -d -o builder -g builder -m 0755 /home/builder/.gradle

# Maven proxy settings so artifact resolution flows through mitmproxy.
COPY builder/maven-settings.xml /home/builder/.m2/settings.xml
RUN chown builder:builder /home/builder/.m2/settings.xml

# Gradle proxy properties (mirrors what Maven settings.xml does).
COPY builder/gradle.properties /home/builder/.gradle/gradle.properties
RUN chown builder:builder /home/builder/.gradle/gradle.properties

COPY builder/sshd_config /etc/ssh/sshd_config
COPY builder/entrypoint.sh /usr/local/bin/builder-entrypoint.sh
RUN chmod +x /usr/local/bin/builder-entrypoint.sh

ENV HTTP_PROXY=http://proxy:8080 \
    HTTPS_PROXY=http://proxy:8080 \
    NO_PROXY=localhost,127.0.0.1,proxy

EXPOSE 2222

# Default to the unprivileged builder user. docker-compose.yml also pins
# `user: "1001:1001"`; baking the USER here covers `docker run` outside
# compose and satisfies DS-0002 (no implicit root container).
USER builder
WORKDIR /home/builder

# tini reaps zombies; the entrypoint sets up host keys + authorized_keys then execs sshd.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/builder-entrypoint.sh"]
