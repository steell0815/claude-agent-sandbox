#!/bin/sh
# keys-init: ensure the builder-keys volume contains an ed25519 keypair.
# Idempotent — re-runs are a no-op once the keys exist.
#
# Runs as the keys-init user (uid 1000). ssh-keygen produces files owned
# by that uid with the canonical 0600 / 0644 perms, which is what the
# agent (also uid 1000) and the builder (uid 1001, only needs the .pub)
# expect — no runtime chown required.

set -eu

KEYDIR="/keys"
KEY="$KEYDIR/id_ed25519"

if [ ! -f "$KEY" ]; then
  echo "keys-init: generating fresh ed25519 keypair in $KEYDIR" >&2
  ssh-keygen -t ed25519 -N "" -f "$KEY" -C "claude-agent-sandbox" -q
else
  echo "keys-init: existing keypair found in $KEYDIR — leaving it alone" >&2
fi

echo "keys-init: done" >&2
