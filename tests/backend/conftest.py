"""
Pytest configuration and fixtures for backend tests.
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import Settings


@pytest.fixture
def client():
    """FastAPI test client fixture."""
    return TestClient(app)


@pytest.fixture
def mock_settings():
    """Mock settings for testing."""
    return Settings(
        azure_translator_key="test-key",
        azure_translator_region="westeurope",
        azure_translator_endpoint="https://api.cognitive.microsofttranslator.com",
    )


@pytest.fixture
def sample_translation_response():
    """Sample translation API response."""
    return [
        {
            "translations": [
                {"text": "Hola mundo", "to": "es"}
            ]
        }
    ]


@pytest.fixture
def sample_detection_response():
    """Sample language detection API response."""
    return [
        {
            "language": "en",
            "score": 1.0,
            "isTranslationSupported": True,
            "isTransliterationSupported": False
        }
    ]

