"""mitmproxy addon: host allowlist, outbound DLP, JSONL audit log.

Loaded via `mitmdump -s policy.py`. Reads optional extra rules from files
pointed to by env vars (so projects can extend defaults without rebuilding):

    ALLOWLIST_EXTRA   path to a file with one host regex per line
    DLP_EXTRA         path to a file with one DLP regex per line
    AUDIT_LOG_PATH    audit log target (default /var/log/proxy/audit.jsonl)
    AUDIT_MAX_BYTES   per-file rotation size (default 50 MiB)
    AUDIT_BACKUPS     rotated file count (default 10)
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
from logging.handlers import RotatingFileHandler
from typing import Iterable

from mitmproxy import http

DEFAULT_ALLOWLIST = (
    r"^api\.anthropic\.com$",
    r"^statsig\.anthropic\.com$",
)

DEFAULT_DLP = (
    r"AKIA[0-9A-Z]{16}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"ghp_[a-zA-Z0-9]{36}",
    r"glpat-[a-zA-Z0-9_\-]{20,}",
    r"eyJ[a-zA-Z0-9_\-]+\.eyJ[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+",
)


def _load_lines(path: str | None) -> tuple[str, ...]:
    if not path or not os.path.isfile(path):
        return ()
    with open(path, "r", encoding="utf-8") as fh:
        return tuple(
            line.strip()
            for line in fh
            if line.strip() and not line.lstrip().startswith("#")
        )


def _compile(patterns: Iterable[str]) -> tuple[re.Pattern[str], ...]:
    return tuple(re.compile(p) for p in patterns)


def _build_audit_logger() -> logging.Logger:
    logger = logging.getLogger("audit")
    logger.setLevel(logging.INFO)
    logger.propagate = False
    if logger.handlers:
        return logger

    path = os.environ.get("AUDIT_LOG_PATH", "/var/log/proxy/audit.jsonl")
    max_bytes = int(os.environ.get("AUDIT_MAX_BYTES", str(50 * 1024 * 1024)))
    backups = int(os.environ.get("AUDIT_BACKUPS", "10"))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    handler = RotatingFileHandler(
        path, maxBytes=max_bytes, backupCount=backups, encoding="utf-8"
    )
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    return logger


class Policy:
    """Allowlist + DLP enforcement with audit logging."""

    def __init__(
        self,
        allowlist: Iterable[str] | None = None,
        dlp: Iterable[str] | None = None,
        audit_logger: logging.Logger | None = None,
    ) -> None:
        allow = tuple(allowlist) if allowlist is not None else DEFAULT_ALLOWLIST + _load_lines(
            os.environ.get("ALLOWLIST_EXTRA")
        )
        deny = tuple(dlp) if dlp is not None else DEFAULT_DLP + _load_lines(
            os.environ.get("DLP_EXTRA")
        )
        self.allow_patterns = _compile(allow)
        self.dlp_patterns = _compile(deny)
        self.audit = audit_logger or _build_audit_logger()

    def host_allowed(self, host: str) -> bool:
        return any(p.search(host) for p in self.allow_patterns)

    def dlp_match(self, body: bytes) -> str | None:
        if not body:
            return None
        try:
            text = body.decode("utf-8", errors="replace")
        except Exception:
            return None
        for p in self.dlp_patterns:
            if p.search(text):
                return p.pattern
        return None

    def evaluate(self, host: str, body: bytes) -> tuple[bool, str | None]:
        if not self.host_allowed(host):
            return False, "host_not_allowed"
        hit = self.dlp_match(body)
        if hit is not None:
            return False, f"dlp:{hit}"
        return True, None

    def log(self, record: dict) -> None:
        self.audit.info(json.dumps(record, separators=(",", ":")))


_policy: Policy | None = None


def policy() -> Policy:
    global _policy
    if _policy is None:
        _policy = Policy()
    return _policy


def request(flow: http.HTTPFlow) -> None:
    p = policy()
    host = flow.request.pretty_host
    body = flow.request.raw_content or b""
    allowed, reason = p.evaluate(host, body)

    record = {
        "ts": time.time(),
        "host": host,
        "method": flow.request.method,
        "path": flow.request.path,
        "allowed": allowed,
        "reason": reason,
        "size": len(body),
    }
    p.log(record)

    if not allowed:
        flow.response = http.Response.make(
            403,
            json.dumps({"error": "blocked_by_proxy", "reason": reason}).encode("utf-8"),
            {"Content-Type": "application/json"},
        )
