import pytest
import sys
import os
from unittest.mock import MagicMock, patch

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Mock google.cloud.datastore before importing app
mock_datastore = MagicMock()
sys.modules['google.cloud.datastore'] = mock_datastore
sys.modules['google.cloud'] = MagicMock()


@pytest.fixture
def app():
    """Create application for testing."""
    from main import app
    app.config['TESTING'] = True
    return app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


@pytest.fixture
def mock_db():
    """Mock the datastore client."""
    with patch('db.client') as mock:
        yield mock
