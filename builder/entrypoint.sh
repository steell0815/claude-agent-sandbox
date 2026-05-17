#!/usr/bin/env bash
# builder-entrypoint.sh — set up SSH state from the keys volume, then exec sshd.
#
# Runs as the unprivileged `builder` user (uid 1001). sshd on port 2222
# means we never need root or CAP_NET_BIND_SERVICE.
#
# Inputs (mounted by docker-compose):
#   /run/builder-keys/id_ed25519.pub   -> authorized_keys for the `builder` user
#
# Side effects (under $HOME/.ssh):
#   ssh_host_ed25519_key{,.pub}        -> generated on first run, persists in $HOME
#   authorized_keys                    -> rewritten each start from the mounted pubkey
#   sshd.pid                           -> sshd's own bookkeeping

set -euo pipefail

SSH_DIR="$HOME/.ssh"
HOST_KEY="$SSH_DIR/ssh_host_ed25519_key"
AUTHORIZED="$SSH_DIR/authorized_keys"
PUBKEY_SRC="/run/builder-keys/id_ed25519.pub"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$HOST_KEY" ]]; then
  ssh-keygen -t ed25519 -N "" -f "$HOST_KEY" -q
fi

if [[ ! -r "$PUBKEY_SRC" ]]; then
  echo "ERROR: builder pubkey not found at $PUBKEY_SRC — is the keys-init service wired up?" >&2
  exit 64
fi

install -m 0600 "$PUBKEY_SRC" "$AUTHORIZED"

echo "builder: sshd listening on :2222 (user=builder, pubkey-only)" >&2
exec /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config
