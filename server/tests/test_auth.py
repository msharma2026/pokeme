import pytest
import json
from unittest.mock import patch, MagicMock


class TestHealthCheck:
    def test_health_check(self, client):
        """Test health check endpoint."""
        response = client.get('/api/health')
        data = json.loads(response.data)

        assert response.status_code == 200
        assert data['success'] is True
        assert data['data']['status'] == 'ok'


class TestAuthEndpoints:
    def test_register_missing_fields(self, client):
        """Test registration with missing fields."""
        response = client.post('/api/auth/register',
            data=json.dumps({'email': 'test@test.com'}),
            content_type='application/json'
        )
        data = json.loads(response.data)

        assert response.status_code == 400
        assert data['success'] is False
        assert data['error']['code'] == 'VALIDATION_ERROR'

    def test_login_missing_fields(self, client):
        """Test login with missing fields."""
        response = client.post('/api/auth/login',
            data=json.dumps({'email': 'test@test.com'}),
            content_type='application/json'
        )
        data = json.loads(response.data)

        assert response.status_code == 400
        assert data['success'] is False
        assert data['error']['code'] == 'VALIDATION_ERROR'

    def test_me_without_token(self, client):
        """Test /me endpoint without token."""
        response = client.get('/api/auth/me')
        data = json.loads(response.data)

        assert response.status_code == 401
        assert data['success'] is False
        assert data['error']['code'] == 'UNAUTHORIZED'

    def test_me_with_invalid_token(self, client):
        """Test /me endpoint with invalid token."""
        response = client.get('/api/auth/me',
            headers={'Authorization': 'Bearer invalid-token'}
        )
        data = json.loads(response.data)

        assert response.status_code == 401
        assert data['success'] is False


class TestMatchEndpoints:
    def test_today_match_without_token(self, client):
        """Test /match/today without token."""
        response = client.get('/api/match/today')
        data = json.loads(response.data)

        assert response.status_code == 401
        assert data['success'] is False

    def test_disconnect_without_token(self, client):
        """Test /match/disconnect without token."""
        response = client.post('/api/match/disconnect')
        data = json.loads(response.data)

        assert response.status_code == 401
        assert data['success'] is False
