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

# Constants for message enhancements
ALLOWED_REACTIONS = ['👍', '❤️', '😂', '😮', '😢']
TYPING_EXPIRY_SECONDS = 10  # Must be longer than polling interval


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


@match_bp.route('/messages', methods=['GET'])
@require_auth
def get_messages():
    """Get messages for the current match."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    # Determine partner ID
    is_user1 = existing_match.get('user1Id') == user_id
    partner_id = existing_match.get('user2Id') if is_user1 else existing_match.get('user1Id')

    # Get messages for this match
    client = get_client()
    query = client.query(kind='Message')
    query.add_filter('matchId', '=', match_id)
    # Note: Sorting in Python to avoid needing a composite index

    # Get all reactions for this match's messages
    reaction_query = client.query(kind='MessageReaction')
    reaction_query.add_filter('matchId', '=', match_id)
    all_reactions = list(reaction_query.fetch())

    # Group reactions by messageId
    reactions_by_message = {}
    for reaction in all_reactions:
        msg_id = reaction.get('messageId')
        if msg_id not in reactions_by_message:
            reactions_by_message[msg_id] = []
        reactions_by_message[msg_id].append({
            'emoji': reaction.get('emoji'),
            'userId': reaction.get('userId'),
            'createdAt': reaction.get('createdAt')
        })

    messages = []
    for msg in query.fetch():
        msg_id = msg.key.name or str(msg.key.id)
        messages.append({
            'id': msg_id,
            'matchId': msg.get('matchId'),
            'senderId': msg.get('senderId'),
            'text': msg.get('text'),
            'createdAt': msg.get('createdAt'),
            'readBy': msg.get('readBy', [msg.get('senderId')]),
            'reactions': reactions_by_message.get(msg_id, [])
        })

    # Sort messages by createdAt
    messages.sort(key=lambda m: m['createdAt'])

    # Check if partner is currently typing
    partner_is_typing = False
    typing_key = client.key('TypingIndicator', f'{match_id}_{partner_id}')
    typing_entity = client.get(typing_key)
    if typing_entity and typing_entity.get('isTyping'):
        updated_at = typing_entity.get('updatedAt')
        if updated_at:
            # Parse the timestamp and check if it's within expiry window
            try:
                updated_time = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                now = datetime.now(pytz.UTC)
                if (now - updated_time).total_seconds() < TYPING_EXPIRY_SECONDS:
                    partner_is_typing = True
            except (ValueError, TypeError):
                pass

    return jsonify({
        'success': True,
        'data': {
            'messages': messages,
            'matchId': match_id,
            'partnerIsTyping': partner_is_typing
        }
    })


@match_bp.route('/messages', methods=['POST'])
@require_auth
def send_message():
    """Send a message to your match."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    if existing_match.get('status') != 'active':
        return jsonify({
            'success': False,
            'error': {
                'code': 'MATCH_INACTIVE',
                'message': 'Cannot send messages to a disconnected match'
            }
        }), 400

    data = request.get_json()
    text = data.get('text', '').strip()

    if not text:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Message text is required'
            }
        }), 400

    if len(text) > 1000:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Message too long (max 1000 characters)'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    # Create message
    client = get_client()
    message_id = str(uuid.uuid4())
    key = client.key('Message', message_id)

    created_at = datetime.utcnow().isoformat() + 'Z'
    entity = Entity(key)
    entity.update({
        'matchId': match_id,
        'senderId': user_id,
        'text': text,
        'readBy': [user_id],  # Sender has read their own message
        'createdAt': created_at
    })

    client.put(entity)

    return jsonify({
        'success': True,
        'data': {
            'message': {
                'id': message_id,
                'matchId': match_id,
                'senderId': user_id,
                'text': text,
                'readBy': [user_id],
                'reactions': [],
                'createdAt': created_at
            }
        }
    })


@match_bp.route('/messages/<message_id>/reactions', methods=['POST'])
@require_auth
def add_reaction(message_id):
    """Add a reaction to a message."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    # Get the message and verify it belongs to this match
    client = get_client()
    msg_key = client.key('Message', message_id)
    message = client.get(msg_key)

    if not message or message.get('matchId') != match_id:
        return jsonify({
            'success': False,
            'error': {
                'code': 'MESSAGE_NOT_FOUND',
                'message': 'Message not found'
            }
        }), 404

    data = request.get_json()
    emoji = data.get('emoji', '')

    if emoji not in ALLOWED_REACTIONS:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': f'Invalid reaction. Allowed: {", ".join(ALLOWED_REACTIONS)}'
            }
        }), 400

    # Create or update reaction
    reaction_key = client.key('MessageReaction', f'{message_id}_{user_id}_{emoji}')
    reaction_entity = Entity(reaction_key)
    reaction_entity.update({
        'messageId': message_id,
        'matchId': match_id,
        'userId': user_id,
        'emoji': emoji,
        'createdAt': datetime.utcnow().isoformat() + 'Z'
    })
    client.put(reaction_entity)

    return jsonify({
        'success': True,
        'data': {
            'reaction': {
                'messageId': message_id,
                'userId': user_id,
                'emoji': emoji,
                'createdAt': reaction_entity.get('createdAt')
            }
        }
    })


@match_bp.route('/messages/<message_id>/reactions/<emoji>', methods=['DELETE'])
@require_auth
def remove_reaction(message_id, emoji):
    """Remove a reaction from a message."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    # Get the message and verify it belongs to this match
    client = get_client()
    msg_key = client.key('Message', message_id)
    message = client.get(msg_key)

    if not message or message.get('matchId') != match_id:
        return jsonify({
            'success': False,
            'error': {
                'code': 'MESSAGE_NOT_FOUND',
                'message': 'Message not found'
            }
        }), 404

    # Delete the reaction (only the user's own reaction)
    reaction_key = client.key('MessageReaction', f'{message_id}_{user_id}_{emoji}')
    client.delete(reaction_key)

    return jsonify({
        'success': True,
        'data': {
            'message': 'Reaction removed'
        }
    })


@match_bp.route('/messages/read', methods=['POST'])
@require_auth
def mark_messages_read():
    """Mark messages as read by the current user."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    data = request.get_json()
    message_ids = data.get('messageIds', [])

    if not message_ids:
        return jsonify({
            'success': False,
            'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'messageIds is required'
            }
        }), 400

    client = get_client()
    updated_count = 0

    for msg_id in message_ids:
        msg_key = client.key('Message', msg_id)
        message = client.get(msg_key)

        if message and message.get('matchId') == match_id:
            read_by = message.get('readBy', [])
            if user_id not in read_by:
                read_by.append(user_id)
                message['readBy'] = read_by
                client.put(message)
                updated_count += 1

    return jsonify({
        'success': True,
        'data': {
            'updatedCount': updated_count
        }
    })


@match_bp.route('/typing', methods=['POST'])
@require_auth
def update_typing():
    """Update typing indicator status."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    if existing_match.get('status') != 'active':
        return jsonify({
            'success': False,
            'error': {
                'code': 'MATCH_INACTIVE',
                'message': 'Cannot update typing status for inactive match'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    data = request.get_json()
    is_typing = data.get('isTyping', False)

    client = get_client()
    typing_key = client.key('TypingIndicator', f'{match_id}_{user_id}')
    typing_entity = Entity(typing_key)
    typing_entity.update({
        'matchId': match_id,
        'userId': user_id,
        'isTyping': is_typing,
        'updatedAt': datetime.utcnow().isoformat() + 'Z'
    })
    client.put(typing_entity)

    return jsonify({
        'success': True,
        'data': {
            'isTyping': is_typing
        }
    })


@match_bp.route('/typing', methods=['GET'])
@require_auth
def get_typing():
    """Get partner's typing status."""
    user_id = request.user_id
    today = get_today_date_string()

    # Find existing match
    existing_match = get_existing_match(user_id, today)

    if not existing_match:
        return jsonify({
            'success': False,
            'error': {
                'code': 'NO_MATCH',
                'message': 'No active match found for today'
            }
        }), 400

    match_id = existing_match.key.name or str(existing_match.key.id)

    # Determine partner ID
    is_user1 = existing_match.get('user1Id') == user_id
    partner_id = existing_match.get('user2Id') if is_user1 else existing_match.get('user1Id')

    # Get partner's typing status
    client = get_client()
    typing_key = client.key('TypingIndicator', f'{match_id}_{partner_id}')
    typing_entity = client.get(typing_key)

    partner_is_typing = False
    if typing_entity and typing_entity.get('isTyping'):
        updated_at = typing_entity.get('updatedAt')
        if updated_at:
            try:
                updated_time = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                now = datetime.now(pytz.UTC)
                if (now - updated_time).total_seconds() < TYPING_EXPIRY_SECONDS:
                    partner_is_typing = True
            except (ValueError, TypeError):
                pass

    return jsonify({
        'success': True,
        'data': {
            'partnerIsTyping': partner_is_typing
        }
    })
