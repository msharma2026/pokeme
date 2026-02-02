from flask import Blueprint, request, jsonify
import random
import string
from datetime import datetime, timedelta
import uuid

from db import get_client, Entity
from config import Config
from models import user_to_dict
from auth import generate_token, get_user_by_id

phone_auth_bp = Blueprint('phone_auth', __name__)

# Test phone numbers for development
TEST_PHONES = {
    '+15305550000': {'scenario': 'happy_path', 'code': '123456'},
    '+15305550001': {'scenario': 'invalid_phone'},
    '+15305550002': {'scenario': 'happy_path', 'code': '654321'},  # Second working test user
    '+15305550003': {'scenario': 'happy_path', 'code': '111111'},  # Third working test user
    '+15305550004': {'scenario': 'invalid_code'},
    '+15305550005': {'scenario': 'max_attempts'},
    '+15305550006': {'scenario': 'service_unavailable'},
}


def normalize_phone(phone):
    """Normalize phone number to E.164 format."""
    # Remove all non-digit characters except +
    cleaned = ''.join(c for c in phone if c.isdigit() or c == '+')
    if not cleaned.startswith('+'):
        cleaned = '+1' + cleaned  # Assume US if no country code
    return cleaned


def generate_code():
    """Generate a 6-digit verification code."""
    return ''.join(random.choices(string.digits, k=6))


def is_test_phone(phone):
    """Check if phone is a test number."""
    return phone in TEST_PHONES


def get_or_create_user_by_phone(phone):
    """Get existing user by phone or create a new one."""
    client = get_client()

    # Check if user exists
    query = client.query(kind='User')
    query.add_filter('phone', '=', phone)
    results = list(query.fetch(limit=1))

    if results:
        return results[0]

    # Create new user
    user_id = str(uuid.uuid4())
    key = client.key('User', user_id)

    entity = Entity(key)
    entity.update({
        'phone': phone,
        'email': None,
        'passwordHash': None,
        'displayName': f'User {phone[-4:]}',
        'major': None,
        'socialPoints': Config.INITIAL_SOCIAL_POINTS,
        'filters': {'preferSameMajor': False},
        'createdAt': datetime.utcnow().isoformat() + 'Z',
        'updatedAt': datetime.utcnow().isoformat() + 'Z'
    })

    client.put(entity)
    return entity


def store_verification_code(phone, code):
    """Store verification code in database."""
    client = get_client()
    key = client.key('VerificationCode', phone)

    entity = Entity(key)
    entity.update({
        'phone': phone,
        'code': code,
        'attempts': 0,
        'createdAt': datetime.utcnow().isoformat() + 'Z',
        'expiresAt': (datetime.utcnow() + timedelta(minutes=10)).isoformat() + 'Z'
    })

    client.put(entity)


def get_verification_code(phone):
    """Get stored verification code."""
    client = get_client()
    key = client.key('VerificationCode', phone)
    return client.get(key)


def delete_verification_code(phone):
    """Delete verification code after successful use."""
    client = get_client()
    key = client.key('VerificationCode', phone)
    client.delete(key)


@phone_auth_bp.route('/send-code', methods=['POST'])
def send_code():
    """Send verification code to phone number."""
    data = request.get_json()
    phone = data.get('phone')

    if not phone:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Phone number is required'
            }
        }), 400

    phone = normalize_phone(phone)

    # Handle test phone numbers
    if is_test_phone(phone):
        test_config = TEST_PHONES[phone]

        if test_config['scenario'] == 'invalid_phone':
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_PHONE',
                    'message': 'Failed to send verification: Invalid phone number'
                }
            }), 400

        if test_config['scenario'] == 'service_unavailable':
            return jsonify({
                'success': False,
                'error': {
                    'code': 'SERVICE_UNAVAILABLE',
                    'message': 'Failed to send verification: Service temporarily unavailable'
                }
            }), 400

        # For happy_path, invalid_code, and max_attempts - pretend to send
        store_verification_code(phone, test_config.get('code', '000000'))

        return jsonify({
            'success': True,
            'data': {
                'message': 'Verification code sent',
                'phone': phone
            }
        })

    # For real phone numbers, we would use Twilio here
    # For now, just generate and store a code (would send via Twilio in production)
    code = generate_code()
    store_verification_code(phone, code)

    # TODO: Integrate actual Twilio SMS sending
    # In production:
    # from twilio.rest import Client
    # client = Client(account_sid, auth_token)
    # client.messages.create(body=f"Your PokeMe code: {code}", from_=TWILIO_NUMBER, to=phone)

    return jsonify({
        'success': True,
        'data': {
            'message': 'Verification code sent',
            'phone': phone
        }
    })


@phone_auth_bp.route('/verify-code', methods=['POST'])
def verify_code():
    """Verify the code and authenticate user."""
    data = request.get_json()
    phone = data.get('phone')
    code = data.get('code')

    if not phone or not code:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Phone number and code are required'
            }
        }), 400

    phone = normalize_phone(phone)

    # Handle test phone numbers
    if is_test_phone(phone):
        test_config = TEST_PHONES[phone]

        if test_config['scenario'] == 'invalid_code':
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_CODE',
                    'message': 'Invalid or expired code'
                }
            }), 401

        if test_config['scenario'] == 'max_attempts':
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_CODE',
                    'message': 'Invalid or expired code'
                }
            }), 401

        if test_config['scenario'] == 'happy_path':
            if code != test_config['code']:
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'INVALID_CODE',
                        'message': 'Invalid or expired code'
                    }
                }), 401

            # Success - get or create user
            user = get_or_create_user_by_phone(phone)
            user_id = user.key.name or str(user.key.id)
            token = generate_token(user_id)

            return jsonify({
                'success': True,
                'data': {
                    'token': token,
                    'user': user_to_dict(user),
                    'isNewUser': user.get('displayName', '').startswith('User ')
                }
            })

    # For real phone numbers
    stored = get_verification_code(phone)

    if not stored:
        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CODE',
                'message': 'Invalid or expired code'
            }
        }), 401

    # Check expiration
    expires_at = datetime.fromisoformat(stored['expiresAt'].replace('Z', '+00:00'))
    if datetime.now(expires_at.tzinfo) > expires_at:
        delete_verification_code(phone)
        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CODE',
                'message': 'Invalid or expired code'
            }
        }), 401

    # Check code
    if stored['code'] != code:
        # Increment attempts
        client = get_client()
        stored['attempts'] = stored.get('attempts', 0) + 1

        if stored['attempts'] >= 5:
            delete_verification_code(phone)
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MAX_ATTEMPTS',
                    'message': 'Too many failed attempts. Please request a new code.'
                }
            }), 401

        client.put(stored)

        return jsonify({
            'success': False,
            'error': {
                'code': 'INVALID_CODE',
                'message': 'Invalid or expired code'
            }
        }), 401

    # Success - delete code and authenticate
    delete_verification_code(phone)

    user = get_or_create_user_by_phone(phone)
    user_id = user.key.name or str(user.key.id)
    token = generate_token(user_id)

    return jsonify({
        'success': True,
        'data': {
            'token': token,
            'user': user_to_dict(user),
            'isNewUser': user.get('displayName', '').startswith('User ')
        }
    })
