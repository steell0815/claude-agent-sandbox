#!/usr/bin/env bash
# bootstrap-ca.sh — generate mitmproxy CA into the shared volume on first run.
#
# Idempotent: exits 0 immediately if the CA already exists.
# mitmproxy auto-generates its CA on first launch; we just trigger that.

set -euo pipefail

CA_DIR="${CA_DIR:-/home/mitmproxy/.mitmproxy}"
CA_PEM="${CA_DIR}/mitmproxy-ca-cert.pem"

if [[ -f "$CA_PEM" ]]; then
  echo "CA already present at $CA_PEM"
  exit 0
fi

mkdir -p "$CA_DIR"
echo "Bootstrapping mitmproxy CA at $CA_DIR ..."

# Launch mitmdump on an OS-assigned port purely to trigger CA generation,
# then kill once the cert appears.
mitmdump --quiet --listen-port 0 --set "confdir=$CA_DIR" >/dev/null 2>&1 &
PID=$!

# Poll for the CA cert (max ~10s).
for _ in $(seq 1 50); do
  if [[ -f "$CA_PEM" ]]; then
    break
  fi
  sleep 0.2
done

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

if [[ ! -f "$CA_PEM" ]]; then
  echo "ERROR: mitmproxy CA was not generated at $CA_PEM" >&2
  exit 1
fi

# The full set mitmproxy writes: ca-cert.pem, ca.pem (cert+key), ca.p12, ca.cer.
# Permissions: cert files world-readable, private-key bundle owner-only.
chmod 0600 "$CA_DIR"/*.p12 "$CA_DIR"/mitmproxy-ca.pem 2>/dev/null || true
chmod 0644 "$CA_PEM" 2>/dev/null || true

echo "CA generated:"
ls -la "$CA_DIR"
