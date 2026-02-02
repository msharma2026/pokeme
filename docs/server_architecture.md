# Server Architecture

## Overview

The PokeMe backend is built with Python and Flask, deployed on Google App Engine, using Cloud Datastore as the database.

## Technology Stack

| Component | Technology |
|-----------|------------|
| Runtime | Python 3.12 |
| Framework | Flask |
| Database | Google Cloud Datastore |
| Authentication | JWT (PyJWT) |
| Password Hashing | bcrypt |
| Hosting | Google App Engine |

## Project Structure

```
server/
├── main.py               # Flask app entry point
├── config.py             # Configuration settings
├── db.py                 # Datastore client
├── auth.py               # Authentication routes & logic
├── match.py              # Matching routes & algorithm
├── models.py             # Data model helpers
├── middleware.py         # JWT auth middleware
├── requirements.txt      # Python dependencies
├── app.yaml              # App Engine configuration
├── .gcloudignore         # Files to exclude from deploy
└── tests/
    ├── conftest.py       # Pytest fixtures
    └── test_auth.py      # API tests
```

## Database Schema (Cloud Datastore)

### Entities

#### User
```python
{
    'email': str,           # Unique email
    'passwordHash': str,    # bcrypt hash
    'displayName': str,     # Display name
    'major': str | None,    # Optional major
    'socialPoints': int,    # Starting: 100
    'filters': {
        'preferSameMajor': bool
    },
    'createdAt': str,       # ISO timestamp
    'updatedAt': str
}
```

#### Match
```python
{
    'date': str,            # "YYYY-MM-DD" format
    'user1Id': str,         # First user
    'user2Id': str,         # Second user
    'status': str,          # "active" | "disconnected"
    'disconnectedBy': str | None,
    'createdAt': str,
    'updatedAt': str
}
```

#### MatchPool
```python
{
    'userId': str,
    'date': str,            # "YYYY-MM-DD"
    'major': str | None,
    'filters': dict,
    'addedAt': str
}
```

## API Endpoints

### Authentication

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | /api/auth/register | Create account | No |
| POST | /api/auth/login | Login | No |
| GET | /api/auth/me | Get current user | Yes |

### Matching

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | /api/match/today | Get today's match | Yes |
| POST | /api/match/disconnect | Disconnect from match | Yes |

### Utility

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | /api/health | Health check | No |

## Matching Algorithm

```python
def get_today_match(user_id):
    today = get_today_date_string()  # Pacific Time

    # 1. Check for existing match
    existing = get_existing_match(user_id, today)
    if existing:
        if existing.status == 'disconnected':
            return {'status': 'disconnected', 'nextMatchAt': tomorrow}
        return {'status': 'matched', 'match': existing}

    # 2. Find partner in pool
    partner = find_partner_in_pool(user_id, today)
    if partner:
        match = create_match(user_id, partner.id, today)
        remove_from_pool(user_id, today)
        remove_from_pool(partner.id, today)
        return {'status': 'matched', 'match': match}

    # 3. Add to pool and wait
    add_to_pool(user_id, today)
    return {'status': 'waiting'}
```

### Date Handling

- Matches reset at midnight Pacific Time (America/Los_Angeles)
- Date format: "YYYY-MM-DD" (e.g., "2026-02-01")
- Each match is keyed by date to ensure daily uniqueness

## Middleware

### Authentication Middleware
- Extracts JWT from Authorization header
- Verifies token signature
- Attaches userId to request object

### Error Handler
- Catches all errors
- Returns consistent error response format
- Logs errors for debugging

## Response Format

### Success Response
```json
{
    "success": true,
    "data": { ... }
}
```

### Error Response
```json
{
    "success": false,
    "error": {
        "code": "ERROR_CODE",
        "message": "Human readable message"
    }
}
```

## Local Development

### Setup

```bash
cd server

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env with your settings
```

### Running Locally

```bash
# Direct Python (port 8080)
python main.py

# With Gunicorn
gunicorn -b :8080 main:app
```

### Running with Datastore Emulator

```bash
# Install emulator
gcloud components install cloud-datastore-emulator

# Start emulator
gcloud beta emulators datastore start

# In another terminal, set env and run
$(gcloud beta emulators datastore env-init)
python main.py
```

## Deployment to App Engine

### Prerequisites

1. Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
2. Create a GCP project
3. Enable App Engine and Datastore APIs

### Deploy

```bash
# Authenticate
gcloud auth login

# Set project
gcloud config set project YOUR-PROJECT-ID

# Deploy
gcloud app deploy

# View logs
gcloud app logs tail -s default

# Open in browser
gcloud app browse
```

### Environment Variables

Set in `app.yaml`:

```yaml
env_variables:
  JWT_SECRET: "your-production-secret-key"
```

## Testing

```bash
# Run tests
pytest

# With verbose output
pytest -v

# With coverage
pytest --cov=. tests/
```
