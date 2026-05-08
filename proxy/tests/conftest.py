import logging
import sys
from pathlib import Path

import pytest

# Make the parent dir importable so `import policy` works without packaging.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


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
