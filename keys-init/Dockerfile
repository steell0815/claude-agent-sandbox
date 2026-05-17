# One-shot service: generates the agent<->builder ed25519 keypair on first
# compose up. Subsequent runs find the keys already present and exit.

FROM alpine:3.20

RUN apk add --no-cache openssh-keygen \
 && adduser -D -u 1000 keys-init

COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
