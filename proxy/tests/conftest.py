import logging
import sys
from pathlib import Path

import pytest

# Make the parent dir importable so `import policy` works without packaging.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture(autouse=True)
def _reset_audit_logger():
    """Drop the module-level "audit" singleton between tests.

    `_build_audit_logger()` short-circuits when `logger.handlers` is non-empty,
    so without this fixture the first test that exercises a real Policy() pins
    the RotatingFileHandler to its tmp_path and later tests silently write to
    that stale path.
    """
    logging.getLogger("audit").handlers.clear()
    yield
    logging.getLogger("audit").handlers.clear()


@pytest.fixture
def silent_audit() -> logging.Logger:
    """An audit logger with a single MemoryHandler so tests can assert records."""
    logger = logging.getLogger("audit-test")
    logger.handlers.clear()
    logger.setLevel(logging.INFO)
    logger.propagate = False
    handler = logging.StreamHandler()
    handler.setLevel(logging.CRITICAL + 1)  # silence stdout in tests
    logger.addHandler(handler)
    return logger
