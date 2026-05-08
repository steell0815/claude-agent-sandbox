"""Unit tests for proxy/policy.py.

The Policy class is exercised directly so we don't need to spin up
mitmproxy; these are pure rule-engine tests.
"""

from __future__ import annotations

import importlib
import json
import logging
import os
from pathlib import Path

import pytest


@pytest.fixture
def policy_module(monkeypatch, tmp_path):
    # Ensure fresh import without inherited env from other tests.
    monkeypatch.delenv("ALLOWLIST_EXTRA", raising=False)
    monkeypatch.delenv("DLP_EXTRA", raising=False)
    monkeypatch.setenv("AUDIT_LOG_PATH", str(tmp_path / "audit.jsonl"))
    import policy

    importlib.reload(policy)
    return policy


def make_policy(policy_module, allowlist=None, dlp=None, silent_audit=None):
    audit = silent_audit or logging.getLogger("policy-test-noop")
    audit.handlers.clear()
    audit.addHandler(logging.NullHandler())
    return policy_module.Policy(
        allowlist=allowlist,
        dlp=dlp,
        audit_logger=audit,
    )


def test_default_allowlist_admits_anthropic_api(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    assert p.host_allowed("api.anthropic.com")


def test_default_allowlist_blocks_unrelated_host(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    assert not p.host_allowed("evil.example.com")


def test_extra_allowlist_loaded_from_file(policy_module, tmp_path, monkeypatch, silent_audit):
    extra = tmp_path / "allow.txt"
    extra.write_text("# my comment\n^github\\.com$\n  \n")
    monkeypatch.setenv("ALLOWLIST_EXTRA", str(extra))
    importlib.reload(policy_module)
    p = policy_module.Policy(audit_logger=silent_audit)
    assert p.host_allowed("api.anthropic.com")  # default still active
    assert p.host_allowed("github.com")
    assert not p.host_allowed("evil.example.com")


def test_dlp_blocks_aws_access_key(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    body = b'{"key":"AKIAIOSFODNN7EXAMPLE","msg":"hi"}'
    assert p.dlp_match(body) is not None


def test_dlp_blocks_private_key_block(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    body = b"-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIB...\n-----END RSA PRIVATE KEY-----"
    assert p.dlp_match(body) is not None


def test_dlp_clean_body_passes(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    assert p.dlp_match(b'{"prompt":"hello"}') is None


def test_dlp_extra_loaded_from_file(policy_module, tmp_path, monkeypatch, silent_audit):
    extra = tmp_path / "dlp.txt"
    extra.write_text("CONFIDENTIAL-[A-Z0-9]{6}\n")
    monkeypatch.setenv("DLP_EXTRA", str(extra))
    importlib.reload(policy_module)
    p = policy_module.Policy(audit_logger=silent_audit)
    assert p.dlp_match(b"see CONFIDENTIAL-AB1234 leak") is not None
    assert p.dlp_match(b"nothing to see") is None


def test_evaluate_returns_block_reason_for_unknown_host(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    allowed, reason = p.evaluate("evil.example.com", b"{}")
    assert allowed is False
    assert reason == "host_not_allowed"


def test_evaluate_returns_dlp_reason(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    allowed, reason = p.evaluate("api.anthropic.com", b'{"k":"AKIAIOSFODNN7EXAMPLE"}')
    assert allowed is False
    assert reason and reason.startswith("dlp:")


def test_evaluate_passes_clean_request(policy_module, silent_audit):
    p = make_policy(policy_module, silent_audit=silent_audit)
    allowed, reason = p.evaluate("api.anthropic.com", b'{"k":"v"}')
    assert allowed is True
    assert reason is None


def test_audit_log_writes_jsonl(policy_module, tmp_path, monkeypatch):
    log_path = tmp_path / "audit.jsonl"
    monkeypatch.setenv("AUDIT_LOG_PATH", str(log_path))
    importlib.reload(policy_module)
    p = policy_module.Policy()  # use real audit logger (RotatingFileHandler)
    p.log({"ts": 0.0, "host": "api.anthropic.com", "allowed": True})
    p.log({"ts": 1.0, "host": "evil.example.com", "allowed": False})
    for h in p.audit.handlers:
        h.flush()
    lines = [ln for ln in log_path.read_text().splitlines() if ln]
    assert len(lines) == 2
    parsed = [json.loads(ln) for ln in lines]
    assert parsed[0]["host"] == "api.anthropic.com"
    assert parsed[1]["allowed"] is False


def test_audit_log_rotates(policy_module, tmp_path, monkeypatch):
    log_path = tmp_path / "audit.jsonl"
    monkeypatch.setenv("AUDIT_LOG_PATH", str(log_path))
    monkeypatch.setenv("AUDIT_MAX_BYTES", "256")
    monkeypatch.setenv("AUDIT_BACKUPS", "2")
    importlib.reload(policy_module)
    p = policy_module.Policy()
    big = "x" * 200
    for i in range(20):
        p.log({"ts": i, "blob": big})
    for h in p.audit.handlers:
        h.flush()
    rotated = sorted(Path(tmp_path).glob("audit.jsonl*"))
    assert len(rotated) >= 2  # primary + at least one backup
