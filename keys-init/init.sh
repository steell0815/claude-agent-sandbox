#!/bin/sh
# keys-init: ensure the builder-keys volume contains an ed25519 keypair.
# Idempotent — re-runs are a no-op once the keys exist.
#
# Ownership/permissions are set so:
#   - agent (uid 1000) reads id_ed25519       (0600, owner=1000)
#   - builder (uid 1001) reads id_ed25519.pub (0644, owner=1000)

set -eu

KEYDIR="/keys"
KEY="$KEYDIR/id_ed25519"

if [ ! -f "$KEY" ]; then
  echo "keys-init: generating fresh ed25519 keypair in $KEYDIR" >&2
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "claude-agent-sandbox" -q
else
  echo "keys-init: existing keypair found in $KEYDIR — leaving it alone" >&2
fi

chown 1000:1000 "$KEY" "$KEY.pub"
chmod 0600 "$KEY"
chmod 0644 "$KEY.pub"

echo "keys-init: done" >&2
