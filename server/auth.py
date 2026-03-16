from flask import Blueprint, request, jsonify
import bcrypt
import jwt
from datetime import datetime, timedelta
import uuid

from db import get_client, Entity
from config import Config
from models import user_to_dict
from middleware import require_auth

auth_bp = Blueprint('auth', __name__)


def create_user(email, password, display_name, major=None):
    """Create a new user in Datastore."""
    client = get_client()

    # Generate unique ID
    user_id = str(uuid.uuid4())
    key = client.key('User', user_id)

    # Hash password
    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    entity = Entity(key)
    entity.update({
        'email': email,
        'passwordHash': password_hash.decode('utf-8'),
        'displayName': display_name,
        'major': major,
        'socialPoints': Config.INITIAL_SOCIAL_POINTS,
        'filters': {'preferSameMajor': False},
        'createdAt': datetime.utcnow().isoformat() + 'Z',
        'updatedAt': datetime.utcnow().isoformat() + 'Z'
    })

    client.put(entity)
    return entity


def get_user_by_email(email):
    """Find a user by email."""
    client = get_client()
    query = client.query(kind='User')
    query.add_filter('email', '=', email)
    results = list(query.fetch(limit=1))
    return results[0] if results else None


def get_user_by_id(user_id):
    """Find a user by ID."""
    client = get_client()
    key = client.key('User', user_id)
    return client.get(key)


def generate_token(user_id, display_name=None):
    """Generate a JWT token, optionally embedding displayName to avoid
    per-request DB lookups in session/message endpoints."""
    payload = {
        'userId': user_id,
        'exp': datetime.utcnow() + timedelta(days=Config.JWT_EXPIRATION_DAYS),
        'iat': datetime.utcnow()
    }
    if display_name:
        payload['displayName'] = display_name
    return jwt.encode(payload, Config.JWT_SECRET, algorithm='HS256')


def get_display_name_for_request(user_id):
    """Return the display name for the current authenticated user.

    Fast path: reads from the JWT claim embedded since the displayName-in-JWT
    change — zero Datastore reads.
    Slow path: falls back to a Datastore lookup for older tokens that pre-date
    this change, then the result is still just one direct key read.
    """
    from flask import request as _req
    name = getattr(_req, 'user_display_name', None)
    if name:
        return name
    user = get_user_by_id(user_id)
    return user.get('displayName', 'Someone') if user else 'Someone'


@auth_bp.route('/register', methods=['POST'])
def register():
    """Register a new user."""
    data = request.get_json()

    # Validation
    email = data.get('email')
    password = data.get('password')
    display_name = data.get('displayName')
    major = data.get('major')

    if not email or not password or not display_name:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Email, password, and displayName are required'
            }
        }), 400

    # Check if user exists
    existing_user = get_user_by_email(email)
    if existing_user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_EXISTS',
                'message': 'User with this email already exists'
            }
        }), 409

    # Create user
    user = create_user(email, password, display_name, major)
    user_id = user.key.name or str(user.key.id)

    # Generate token (embed displayName so session endpoints skip DB lookup)
    token = generate_token(user_id, display_name)

    return jsonify({
        'success': True,
        'data': {
            'token': token,
            'user': user_to_dict(user)
        }
    }), 201


@auth_bp.route('/login', methods=['POST'])
def login():
    """Authenticate a user."""
    data = request.get_json()

    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Email and password are required'
            }
        }), 400

    # Find user
    user = get_user_by_email(email)
    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Invalid email or password'
            }
        }), 401

    # Check password
    if not bcrypt.checkpw(password.encode('utf-8'), user['passwordHash'].encode('utf-8')):
        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CREDENTIALS',
                'message': 'Invalid email or password'
            }
        }), 401

    # Generate token (embed displayName so session endpoints skip DB lookup)
    user_id = user.key.name or str(user.key.id)
    token = generate_token(user_id, user.get('displayName'))

    return jsonify({
        'success': True,
        'data': {
            'token': token,
            'user': user_to_dict(user)
        }
    })


@auth_bp.route('/me', methods=['GET'])
@require_auth
def get_me():
    """Get the current authenticated user."""
    user = get_user_by_id(request.user_id)

    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'User not found'
            }
        }), 404

    return jsonify({
        'success': True,
        'data': user_to_dict(user)
    })


@auth_bp.route('/profile', methods=['PUT'])
@require_auth
def update_profile():
    """Update user profile."""
    user = get_user_by_id(request.user_id)

    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'User not found'
            }
        }), 404

    data = request.get_json()

    # Update allowed fields
    if 'displayName' in data:
        user['displayName'] = data['displayName']
    if 'major' in data:
        user['major'] = data['major']
    if 'bio' in data:
        user['bio'] = data['bio']
    if 'socials' in data:
        user['socials'] = data['socials']
    if 'sports' in data:
        user['sports'] = data['sports']
    if 'collegeYear' in data:
        user['collegeYear'] = data['collegeYear']
    if 'availability' in data:
        user['availability'] = data['availability']

    user['updatedAt'] = datetime.utcnow().isoformat() + 'Z'

    client = get_client()
    client.put(user)

    return jsonify({
        'success': True,
        'data': user_to_dict(user)
    })


@auth_bp.route('/account', methods=['DELETE'])
@require_auth
def delete_account():
    """Permanently delete the current user and all their data."""
    user_id = request.user_id
    client = get_client()

    # Collect all keys to delete, then issue a single batch delete.
    keys_to_delete = []

    # Pokes (outgoing and incoming)
    for field in ['fromUserId', 'toUserId']:
        q = client.query(kind='Poke')
        q.add_filter(field, '=', user_id)
        q.keys_only()
        keys_to_delete.extend(item.key for item in q.fetch())

    # Matches and all their child entities
    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter(field, '=', user_id)
        for match in q.fetch():
            match_id = match.key.name or str(match.key.id)
            keys_to_delete.append(match.key)
            for kind in ['Message', 'MessageReaction', 'Session']:
                mq = client.query(kind=kind)
                mq.add_filter('matchId', '=', match_id)
                mq.keys_only()
                keys_to_delete.extend(item.key for item in mq.fetch())

    keys_to_delete.append(client.key('User', user_id))

    # Datastore delete_multi accepts up to 500 keys per call
    chunk_size = 500
    for i in range(0, len(keys_to_delete), chunk_size):
        client.delete_multi(keys_to_delete[i:i + chunk_size])

    return jsonify({'success': True, 'data': {}})


@auth_bp.route('/profile-picture', methods=['POST'])
@require_auth
def upload_profile_picture():
    """Upload a profile picture (base64 encoded)."""
    user = get_user_by_id(request.user_id)

    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'User not found'
            }
        }), 404

    data = request.get_json()
    image_data = data.get('image')

    if not image_data:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Image data is required'
            }
        }), 400

    # Store as base64 data URL (for simplicity)
    # In production, you'd upload to Cloud Storage and store the URL
    user['profilePicture'] = image_data
    user['updatedAt'] = datetime.utcnow().isoformat() + 'Z'

    # Exclude large fields from indexes (Datastore has 1500 byte index limit)
    efi = set(user.exclude_from_indexes)
    efi.add('profilePicture')
    user.exclude_from_indexes = efi

    client = get_client()
    client.put(user)

    return jsonify({
        'success': True,
        'data': user_to_dict(user)
    })
