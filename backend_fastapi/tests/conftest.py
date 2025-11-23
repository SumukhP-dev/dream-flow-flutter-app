"""
Pytest configuration and fixtures for tests.

Mocks external dependencies that may not be available during testing.
"""

import sys
from unittest.mock import MagicMock

# Mock moviepy before importing services
sys.modules['moviepy'] = MagicMock()
sys.modules['moviepy.editor'] = MagicMock()

