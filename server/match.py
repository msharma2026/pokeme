from flask import Blueprint, request, jsonify
from datetime import datetime, timedelta
import pytz
import uuid
import random

from db import get_client, Entity
from config import Config
from models import user_to_dict, match_to_dict
from middleware import require_auth
from auth import get_user_by_id

match_bp = Blueprint('match', __name__)


def get_today_date_string():
    """Get today's date string in Pacific Time."""
    tz = pytz.timezone(Config.TIMEZONE)
    now = datetime.now(tz)
    return now.strftime('%Y-%m-%d')


def get_next_midnight():
    """Get the next midnight timestamp in Pacific Time."""
    tz = pytz.timezone(Config.TIMEZONE)
    now = datetime.now(tz)
    tomorrow = now + timedelta(days=1)
    midnight = tomorrow.replace(hour=0, minute=0, second=0, microsecond=0)
    return midnight.isoformat()


def get_existing_match(user_id, date):
    """Check if user already has a match today."""
    client = get_client()

    # Check as user1
    query = client.query(kind='Match')
    query.add_filter('date', '=', date)
    query.add_filter('user1Id', '=', user_id)
    results = list(query.fetch(limit=1))

    if results:
        return results[0]

    # Check as user2
    query = client.query(kind='Match')
    query.add_filter('date', '=', date)
    query.add_filter('user2Id', '=', user_id)
    results = list(query.fetch(limit=1))

    if results:
        return results[0]

    return None


def get_pool_users(date):
    """Get all users in the matching pool for today."""
    client = get_client()
    query = client.query(kind='MatchPool')
    query.add_filter('date', '=', date)
    return list(query.fetch())


def add_to_pool(user_id, date, major=None, filters=None):
    """Add user to the matching pool."""
    client = get_client()
    key = client.key('MatchPool', f'{date}_{user_id}')

    entity = Entity(key)
    entity.update({
        'userId': user_id,
        'date': date,
        'major': major,
        'filters': filters or {},
        'addedAt': datetime.utcnow().isoformat() + 'Z'
    })

    client.put(entity)


def remove_from_pool(user_id, date):
    """Remove user from the matching pool."""
    client = get_client()
    key = client.key('MatchPool', f'{date}_{user_id}')
    client.delete(key)


def create_match(user1_id, user2_id, date):
    """Create a new match between two users."""
    client = get_client()
    match_id = str(uuid.uuid4())
    key = client.key('Match', match_id)

    entity = Entity(key)
    entity.update({
        'date': date,
        'user1Id': user1_id,
        'user2Id': user2_id,
        'status': 'active',
        'disconnectedBy': None,
        'user1Pokes': 0,
        'user2Pokes': 0,
        'createdAt': datetime.utcnow().isoformat() + 'Z',
        'updatedAt': datetime.utcnow().isoformat() + 'Z'
    })

    client.put(entity)
    return entity


def find_partner_in_pool(user_id, date, user_major=None, prefer_same_major=False):
    """Find a matching partner in the pool."""
    pool_users = get_pool_users(date)

    # Filter out self
    candidates = [p for p in pool_users if p.get('userId') != user_id]

    if not candidates:
        return None

    # Apply major preference if set
    if prefer_same_major and user_major:
        same_major_candidates = [p for p in candidates if p.get('major') == user_major]
        if same_major_candidates:
            candidates = same_major_candidates

    # Random selection
    return random.choice(candidates)


def format_match_for_user(match, user_id):
    """Format match entity for API response with partner info."""
    is_user1 = match.get('user1Id') == user_id
    partner_id = match.get('user2Id') if is_user1 else match.get('user1Id')
    partner = get_user_by_id(partner_id)

    # Get poke counts from perspective of current user
    my_pokes = match.get('user1Pokes', 0) if is_user1 else match.get('user2Pokes', 0)
    partner_pokes = match.get('user2Pokes', 0) if is_user1 else match.get('user1Pokes', 0)

    return {
        'id': match.key.name or str(match.key.id),
        'date': match.get('date'),
        'partnerId': partner_id,
        'partnerName': partner.get('displayName') if partner else 'Unknown',
        'partnerMajor': partner.get('major') if partner else None,
        'status': match.get('status'),
        'myPokes': my_pokes,
        'partnerPokes': partner_pokes,
        'createdAt': match.get('createdAt')
    }


@match_bp.route('/today', methods=['GET'])
@require_auth
def get_today_match():
    """Get or create today's match for the user."""
    user_id = request.user_id
    today = get_today_date_string()

    # Get user info for matching preferences
    user = get_user_by_id(user_id)
    if not user:
        return jsonify({
            'success': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'User not found'
            }
        }), 404

    user_major = user.get('major')
    user_filters = user.get('filters', {})
    prefer_same_major = user_filters.get('preferSameMajor', False)

    # Check for existing match
    existing_match = get_existing_match(user_id, today)

    if existing_match:
        if existing_match.get('status') == 'disconnected':
            return jsonify({
                'success': True,
                'data': {
                    'match': None,
                    'status': 'disconnected',
                    'message': 'You disconnected today. New match available tomorrow.',
                    'nextMatchAt': get_next_midnight()
                }
            })

        formatted_match = format_match_for_user(existing_match, user_id)
        return jsonify({
            'success': True,
            'data': {
                'match': formatted_match,
                'status': 'matched'
            }
        })

    # Try to find a partner in the pool
    partner = find_partner_in_pool(user_id, today, user_major, prefer_same_major)

    if partner:
        partner_id = partner.get('userId')

        # Create match and remove both from pool
        match = create_match(user_id, partner_id, today)
        remove_from_pool(user_id, today)
        remove_from_pool(partner_id, today)

        formatted_match = format_match_for_user(match, user_id)
        return jsonify({
            'success': True,
            'data': {
                'match': formatted_match,
                'status': 'matched'
            }
        })

    # Add to pool and wait
    add_to_pool(user_id, today, user_major, user_filters)

    return jsonify({
        'success': True,
        'data': {
            'match': None,
            'status': 'waiting',
            'message': "You're in the matching pool. Check back soon!"
        }
    })


@match_bp.route('/disconnect', methods=['POST'])
@require_auth
def disconnect():
    """Disconnect from the current match."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'DISCONNECT_FAILED',
                'message': 'No active match found for today'
            }
        }), 400

    if existing_match.get('status') == 'disconnected':
        return jsonify({
            'success': False,
            'error': {
                'code': 'DISCONNECT_FAILED',
                'message': 'Already disconnected'
            }
        }), 400

    # Update match status
    client = get_client()
    existing_match['status'] = 'disconnected'
    existing_match['disconnectedBy'] = user_id
    existing_match['updatedAt'] = datetime.utcnow().isoformat() + 'Z'
    client.put(existing_match)

    return jsonify({
        'success': True,
        'data': {
            'message': 'Match disconnected. New match available tomorrow.',
            'nextMatchAt': get_next_midnight()
        }
    })


@match_bp.route('/poke', methods=['POST'])
@require_auth
def poke():
    """Poke your current match."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'POKE_FAILED',
                'message': 'No active match found for today'
            }
        }), 400

    if existing_match.get('status') != 'active':
        return jsonify({
            'success': False,
            'error': {
                'code': 'POKE_FAILED',
                'message': 'Cannot poke a disconnected match'
            }
        }), 400

    # Increment poke count for the current user
    client = get_client()
    is_user1 = existing_match.get('user1Id') == user_id

    if is_user1:
        existing_match['user1Pokes'] = existing_match.get('user1Pokes', 0) + 1
    else:
        existing_match['user2Pokes'] = existing_match.get('user2Pokes', 0) + 1

    existing_match['updatedAt'] = datetime.utcnow().isoformat() + 'Z'
    client.put(existing_match)

    formatted_match = format_match_for_user(existing_match, user_id)

    return jsonify({
        'success': True,
        'data': {
            'match': formatted_match,
            'message': 'Poked!'
        }
    })
