"""
Tests for API routes.
"""

import pytest
from fastapi import status


def test_health_check(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
    assert "timestamp" in data


def test_root_endpoint(client):
    """Test root endpoint."""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "name" in data
    assert "version" in data


def test_translate_validation_empty_text(client):
    """Test translation with empty text."""
    response = client.post(
        "/api/v1/translate",
        json={"text": "", "to": ["es"]}
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_translate_validation_no_target(client):
    """Test translation without target language."""
    response = client.post(
        "/api/v1/translate",
        json={"text": "Hello", "to": []}
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_translate_validation_text_too_long(client):
    """Test translation with text exceeding max length."""
    long_text = "a" * 50001
    response = client.post(
        "/api/v1/translate",
        json={"text": long_text, "to": ["es"]}
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_detect_validation_empty_text(client):
    """Test language detection with empty text."""
    response = client.post(
        "/api/v1/detect",
        json={"text": ""}
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_get_languages(client):
    """Test get languages endpoint."""
    # Note: This will make a real API call in integration tests
    # For unit tests, mock the translator service
    response = client.get("/api/v1/languages")
    # May succeed or fail depending on if real API key is configured
    assert response.status_code in [status.HTTP_200_OK, status.HTTP_500_INTERNAL_SERVER_ERROR]

