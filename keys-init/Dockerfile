# One-shot service: generates the agent<->builder ed25519 keypair on first
# compose up. Subsequent runs find the keys already present and exit.
#
# Runs as a non-root user (uid 1000) so the files it writes are immediately
# owned by the agent's uid — no runtime chown needed. The /keys mountpoint
# is created in the image with matching ownership so Docker propagates it
# to an empty named volume on first mount.

FROM alpine:3.20

# DL3018 ignored: this image only runs `ssh-keygen` once at first compose
# up to produce an ed25519 keypair. The openssh-keygen version is not
# part of any security surface — bumping it with alpine:3.20 is fine.
# hadolint ignore=DL3018
RUN apk add --no-cache openssh-keygen \
 && adduser -D -u 1000 keys-init \
 && mkdir -p /keys \
 && chown keys-init:keys-init /keys

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

USER keys-init
ENTRYPOINT ["/usr/local/bin/init.sh"]
