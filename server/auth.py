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


def generate_token(user_id):
    """Generate a JWT token."""
    payload = {
        'userId': user_id,
        'exp': datetime.utcnow() + timedelta(days=Config.JWT_EXPIRATION_DAYS),
        'iat': datetime.utcnow()
    }
    return jwt.encode(payload, Config.JWT_SECRET, algorithm='HS256')


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

    # Generate token
    token = generate_token(user_id)

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

    # Generate token
    user_id = user.key.name or str(user.key.id)
    token = generate_token(user_id)

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
