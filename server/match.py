from flask import Blueprint, request, jsonify
from datetime import datetime
import pytz
import uuid

from db import get_client, Entity
from config import Config
from models import user_to_dict, expand_availability, session_to_dict
from middleware import require_auth
from auth import get_user_by_id
from recommendation import rank_discover_candidates

match_bp = Blueprint('match', __name__)

# Constants
ALLOWED_REACTIONS = ['👍', '❤️', '😂', '😮', '😢']
TYPING_EXPIRY_SECONDS = 10


def error_response(code, message, status=400):
    return jsonify({
        'success': False,
        'error': {'code': code, 'message': message}
    }), status


def get_match_for_user(match_id, user_id):
    """Get a match and verify the user is part of it. Returns (match, partner_id)."""
    client = get_client()
    key = client.key('Match', match_id)
    match = client.get(key)

    if not match:
        return None, None

    if match.get('user1Id') != user_id and match.get('user2Id') != user_id:
        return None, None

    partner_id = match.get('user2Id') if match.get('user1Id') == user_id else match.get('user1Id')
    return match, partner_id


# ──────────────────────────────────────────────
# Discovery & Poke
# ──────────────────────────────────────────────

@match_bp.route('/discover', methods=['GET'])
@require_auth
def discover():
    """Get profiles to browse, optionally filtered by sport and AI-ranked by compatibility."""
    user_id = request.user_id
    sport_filter = request.args.get('sport')

    user = get_user_by_id(user_id)
    if not user:
        return error_response('USER_NOT_FOUND', 'User not found', 404)

    client = get_client()

    # Get user IDs the current user has already poked
    poke_query = client.query(kind='Poke')
    poke_query.add_filter('fromUserId', '=', user_id)
    poked_ids = set(p.get('toUserId') for p in poke_query.fetch())

    # Get user IDs the current user is already matched with
    matched_ids = set()
    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter(field, '=', user_id)
        q.add_filter('status', '=', 'active')
        for m in q.fetch():
            other = m.get('user2Id') if field == 'user1Id' else m.get('user1Id')
            matched_ids.add(other)

    exclude_ids = poked_ids | matched_ids | {user_id}

    # Fetch all users and filter
    all_users = list(client.query(kind='User').fetch())

    candidate_entities = []
    for u in all_users:
        uid = u.key.name or str(u.key.id)
        if uid in exclude_ids:
            continue

        # If sport filter is set, only include users who play that sport
        if sport_filter:
            user_sports = u.get('sports', [])
            sport_names = [s.get('sport', '').lower() for s in user_sports]
            if sport_filter.lower() not in sport_names:
                continue

        candidate_entities.append(u)

    ranked_candidates = rank_discover_candidates(user, candidate_entities)

    profiles = []
    for ranked in ranked_candidates:
        profile = user_to_dict(ranked['candidate'])
        profile['recommendationScore'] = ranked['recommendation']['score']
        profile['recommendationReasons'] = ranked['recommendation']['reasons']
        profile['recommendationBreakdown'] = ranked['recommendation']['breakdown']
        profiles.append(profile)

    return jsonify({
        'success': True,
        'data': {
            'profiles': profiles,
            'rankingModel': 'claude-ai-v1'
        }
    })


@match_bp.route('/poke/<target_user_id>', methods=['POST'])
@require_auth
def poke(target_user_id):
    """Poke a user. If mutual, auto-creates a match."""
    user_id = request.user_id

    if user_id == target_user_id:
        return error_response('POKE_FAILED', 'Cannot poke yourself')

    target = get_user_by_id(target_user_id)
    if not target:
        return error_response('USER_NOT_FOUND', 'User not found', 404)

    client = get_client()

    # Check if already poked
    poke_key = client.key('Poke', f'{user_id}_{target_user_id}')
    if client.get(poke_key):
        return jsonify({
            'success': True,
            'data': {'status': 'already_poked', 'message': 'You already poked this user'}
        })

    # Create poke
    poke_entity = Entity(poke_key)
    poke_entity.update({
        'fromUserId': user_id,
        'toUserId': target_user_id,
        'createdAt': datetime.utcnow().isoformat() + 'Z'
    })
    client.put(poke_entity)

    # Check for mutual poke
    reverse_key = client.key('Poke', f'{target_user_id}_{user_id}')
    if client.get(reverse_key):
        # Mutual poke — create match
        match_id = str(uuid.uuid4())
        match_entity = Entity(client.key('Match', match_id))
        match_entity.update({
            'user1Id': user_id,
            'user2Id': target_user_id,
            'status': 'active',
            'createdAt': datetime.utcnow().isoformat() + 'Z'
        })
        client.put(match_entity)

        partner = user_to_dict(target)
        return jsonify({
            'success': True,
            'data': {
                'status': 'matched',
                'message': "It's a match!",
                'match': {
                    'id': match_id,
                    'partnerId': target_user_id,
                    'partnerName': partner.get('displayName'),
                    'partnerSports': partner.get('sports', []),
                    'partnerCollegeYear': partner.get('collegeYear'),
                    'partnerProfilePicture': partner.get('profilePicture'),
                    'status': 'active',
                    'createdAt': match_entity.get('createdAt')
                }
            }
        })

    return jsonify({
        'success': True,
        'data': {'status': 'poked', 'message': 'Poke sent!'}
    })


@match_bp.route('/pokes/incoming', methods=['GET'])
@require_auth
def get_incoming_pokes():
    """Get all incoming pokes for the current user (excluding already-matched users)."""
    user_id = request.user_id
    client = get_client()

    # Get matched user IDs (same pattern as discover)
    matched_ids = set()
    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter('status', '=', 'active')
        q.add_filter(field, '=', user_id)
        for m in q.fetch():
            other = m.get('user2Id') if field == 'user1Id' else m.get('user1Id')
            matched_ids.add(other)

    # Query pokes where toUserId = current user
    poke_query = client.query(kind='Poke')
    poke_query.add_filter('toUserId', '=', user_id)
    incoming_pokes = list(poke_query.fetch())

    # Filter out pokes from matched users, enrich with user data
    pokes = []
    for p in incoming_pokes:
        from_id = p.get('fromUserId')
        if from_id in matched_ids:
            continue

        from_user = get_user_by_id(from_id)
        if not from_user:
            continue

        pokes.append({
            'id': p.key.name or str(p.key.id),
            'fromUserId': from_id,
            'createdAt': p.get('createdAt'),
            'fromUser': user_to_dict(from_user)
        })

    pokes.sort(key=lambda x: x.get('createdAt', ''), reverse=True)

    return jsonify({
        'success': True,
        'data': {'pokes': pokes, 'count': len(pokes)}
    })


# ──────────────────────────────────────────────
# Matches
# ──────────────────────────────────────────────

@match_bp.route('/admin/debug-discover', methods=['GET'])
@require_auth
def debug_discover():
    """Debug endpoint to see why a user might not appear in discover."""
    user_id = request.user_id
    sport_filter = request.args.get('sport')
    client = get_client()

    # Get poked IDs
    poke_query = client.query(kind='Poke')
    poke_query.add_filter('fromUserId', '=', user_id)
    poked_ids = set(p.get('toUserId') for p in poke_query.fetch())

    # Get matched IDs
    matched_ids = set()
    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter(field, '=', user_id)
        q.add_filter('status', '=', 'active')
        for m in q.fetch():
            other = m.get('user2Id') if field == 'user1Id' else m.get('user1Id')
            matched_ids.add(other)

    exclude_ids = poked_ids | matched_ids | {user_id}

    # Check all users with the sport
    all_users = list(client.query(kind='User').fetch())
    all_with_sport = []
    for u in all_users:
        uid = u.key.name or str(u.key.id)
        user_sports = u.get('sports', [])
        sport_names = [s.get('sport', '').lower() for s in user_sports]
        if sport_filter and sport_filter.lower() in sport_names:
            all_with_sport.append({
                'id': uid,
                'name': u.get('displayName'),
                'excluded': uid in exclude_ids,
                'reason': 'poked' if uid in poked_ids else ('matched' if uid in matched_ids else ('self' if uid == user_id else None))
            })

    return jsonify({
        'success': True,
        'data': {
            'userId': user_id,
            'sportFilter': sport_filter,
            'pokedIds': list(poked_ids),
            'matchedIds': list(matched_ids),
            'usersWithSport': all_with_sport
        }
    })


@match_bp.route('/admin/reset', methods=['POST'])
@require_auth
def reset_user_data():
    """Delete all pokes and matches for the current user (for testing)."""
    user_id = request.user_id
    client = get_client()

    deleted_pokes = 0
    deleted_matches = 0

    # Delete outgoing pokes
    q = client.query(kind='Poke')
    q.add_filter('fromUserId', '=', user_id)
    for p in q.fetch():
        client.delete(p.key)
        deleted_pokes += 1

    # Delete incoming pokes
    q = client.query(kind='Poke')
    q.add_filter('toUserId', '=', user_id)
    for p in q.fetch():
        client.delete(p.key)
        deleted_pokes += 1

    # Delete matches where user is user1 or user2
    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter(field, '=', user_id)
        for m in q.fetch():
            client.delete(m.key)
            deleted_matches += 1

    return jsonify({
        'success': True,
        'data': {'deletedPokes': deleted_pokes, 'deletedMatches': deleted_matches}
    })


@match_bp.route('/matches', methods=['GET'])
@require_auth
def get_matches():
    """Get all active matches for the current user."""
    user_id = request.user_id
    client = get_client()

    matches = []

    for field in ['user1Id', 'user2Id']:
        q = client.query(kind='Match')
        q.add_filter(field, '=', user_id)
        q.add_filter('status', '=', 'active')

        for m in q.fetch():
            partner_id = m.get('user2Id') if field == 'user1Id' else m.get('user1Id')
            partner = get_user_by_id(partner_id)
            pd = user_to_dict(partner) if partner else {}

            match_id = m.key.name or str(m.key.id)

            # Get last message
            msg_query = client.query(kind='Message')
            msg_query.add_filter('matchId', '=', match_id)
            msgs = list(msg_query.fetch())
            msgs.sort(key=lambda x: x.get('createdAt', ''))
            last_message = None
            if msgs:
                last = msgs[-1]
                last_message = {
                    'text': last.get('text'),
                    'senderId': last.get('senderId'),
                    'createdAt': last.get('createdAt')
                }

            matches.append({
                'id': match_id,
                'partnerId': partner_id,
                'partnerName': pd.get('displayName', 'Unknown'),
                'partnerSports': pd.get('sports', []),
                'partnerCollegeYear': pd.get('collegeYear'),
                'partnerProfilePicture': pd.get('profilePicture'),
                'status': m.get('status'),
                'lastMessage': last_message,
                'createdAt': m.get('createdAt')
            })

    # Sort by most recent activity
    matches.sort(
        key=lambda m: (m.get('lastMessage') or {}).get('createdAt', m.get('createdAt', '')),
        reverse=True
    )

    return jsonify({
        'success': True,
        'data': {'matches': matches}
    })


# ──────────────────────────────────────────────
# Messages (scoped to matchId)
# ──────────────────────────────────────────────

@match_bp.route('/matches/<match_id>/messages', methods=['GET'])
@require_auth
def get_messages(match_id):
    """Get messages for a specific match."""
    user_id = request.user_id

    match, partner_id = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    client = get_client()

    # Messages
    query = client.query(kind='Message')
    query.add_filter('matchId', '=', match_id)

    # Reactions
    reaction_query = client.query(kind='MessageReaction')
    reaction_query.add_filter('matchId', '=', match_id)
    all_reactions = list(reaction_query.fetch())

    reactions_by_message = {}
    for r in all_reactions:
        mid = r.get('messageId')
        if mid not in reactions_by_message:
            reactions_by_message[mid] = []
        reactions_by_message[mid].append({
            'emoji': r.get('emoji'),
            'userId': r.get('userId'),
            'createdAt': r.get('createdAt')
        })

    messages = []
    for msg in query.fetch():
        msg_id = msg.key.name or str(msg.key.id)
        msg_dict = {
            'id': msg_id,
            'matchId': msg.get('matchId'),
            'senderId': msg.get('senderId'),
            'text': msg.get('text'),
            'createdAt': msg.get('createdAt'),
            'readBy': msg.get('readBy', [msg.get('senderId')]),
            'reactions': reactions_by_message.get(msg_id, [])
        }
        if msg.get('type'):
            msg_dict['type'] = msg.get('type')
        if msg.get('metadata'):
            msg_dict['metadata'] = msg.get('metadata')
        messages.append(msg_dict)

    messages.sort(key=lambda m: m['createdAt'])

    # Typing indicator
    partner_is_typing = False
    typing_key = client.key('TypingIndicator', f'{match_id}_{partner_id}')
    typing_entity = client.get(typing_key)
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
            'messages': messages,
            'matchId': match_id,
            'partnerIsTyping': partner_is_typing
        }
    })


@match_bp.route('/matches/<match_id>/messages', methods=['POST'])
@require_auth
def send_message(match_id):
    """Send a message to a specific match."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    if match.get('status') != 'active':
        return error_response('MATCH_INACTIVE', 'Match is no longer active')

    data = request.get_json()
    text = data.get('text', '').strip()

    if not text:
        return error_response('VALIDATION_ERROR', 'Message text is required')
    if len(text) > 1000:
        return error_response('VALIDATION_ERROR', 'Message too long (max 1000 characters)')

    client = get_client()
    message_id = str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat() + 'Z'

    entity = Entity(client.key('Message', message_id))
    entity.update({
        'matchId': match_id,
        'senderId': user_id,
        'text': text,
        'readBy': [user_id],
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
                'type': 'text',
                'readBy': [user_id],
                'reactions': [],
                'createdAt': created_at
            }
        }
    })


@match_bp.route('/matches/<match_id>/messages/<message_id>/reactions', methods=['POST'])
@require_auth
def add_reaction(match_id, message_id):
    """Add a reaction to a message."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    client = get_client()
    msg_key = client.key('Message', message_id)
    message = client.get(msg_key)

    if not message or message.get('matchId') != match_id:
        return error_response('MESSAGE_NOT_FOUND', 'Message not found', 404)

    data = request.get_json()
    emoji = data.get('emoji', '')

    if emoji not in ALLOWED_REACTIONS:
        return error_response('VALIDATION_ERROR', f'Invalid reaction. Allowed: {", ".join(ALLOWED_REACTIONS)}')

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


@match_bp.route('/matches/<match_id>/messages/<message_id>/reactions/<emoji>', methods=['DELETE'])
@require_auth
def remove_reaction(match_id, message_id, emoji):
    """Remove a reaction from a message."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    client = get_client()
    msg_key = client.key('Message', message_id)
    message = client.get(msg_key)

    if not message or message.get('matchId') != match_id:
        return error_response('MESSAGE_NOT_FOUND', 'Message not found', 404)

    reaction_key = client.key('MessageReaction', f'{message_id}_{user_id}_{emoji}')
    client.delete(reaction_key)

    return jsonify({
        'success': True,
        'data': {'message': 'Reaction removed'}
    })


@match_bp.route('/matches/<match_id>/messages/read', methods=['POST'])
@require_auth
def mark_messages_read(match_id):
    """Mark messages as read."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    data = request.get_json()
    message_ids = data.get('messageIds', [])

    if not message_ids:
        return error_response('VALIDATION_ERROR', 'messageIds is required')

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
        'data': {'updatedCount': updated_count}
    })


@match_bp.route('/matches/<match_id>/typing', methods=['POST'])
@require_auth
def update_typing(match_id):
    """Update typing indicator."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

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
        'data': {'isTyping': is_typing}
    })


@match_bp.route('/matches/<match_id>/typing', methods=['GET'])
@require_auth
def get_typing(match_id):
    """Get partner's typing status."""
    user_id = request.user_id

    match, partner_id = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

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
        'data': {'partnerIsTyping': partner_is_typing}
    })


# ──────────────────────────────────────────────
# Sessions (Play Proposals)
# ──────────────────────────────────────────────

@match_bp.route('/matches/<match_id>/compatible-times', methods=['GET'])
@require_auth
def get_compatible_times(match_id):
    """Compute overlap of both users' expanded availability + shared sports."""
    user_id = request.user_id

    match, partner_id = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    user = get_user_by_id(user_id)
    partner = get_user_by_id(partner_id)

    if not user or not partner:
        return error_response('USER_NOT_FOUND', 'User not found', 404)

    # Expand availability
    user_avail = expand_availability(user.get('availability', {}))
    partner_avail = expand_availability(partner.get('availability', {}))

    # Find overlapping hours per day
    compatible_times = {}
    all_days = set(user_avail.keys()) & set(partner_avail.keys())
    for day in all_days:
        overlap = sorted(user_avail[day] & partner_avail[day])
        if overlap:
            compatible_times[day] = [f'{h}:00' for h in overlap]

    # Find shared sports
    user_sports = {s.get('sport', '').lower(): s for s in user.get('sports', [])}
    partner_sports = {s.get('sport', '').lower(): s for s in partner.get('sports', [])}

    shared_sports = []
    for sport_key in set(user_sports.keys()) & set(partner_sports.keys()):
        shared_sports.append({
            'sport': user_sports[sport_key].get('sport'),
            'userLevel': user_sports[sport_key].get('skillLevel'),
            'partnerLevel': partner_sports[sport_key].get('skillLevel'),
        })

    return jsonify({
        'success': True,
        'data': {
            'compatibleTimes': compatible_times,
            'sharedSports': shared_sports
        }
    })


@match_bp.route('/matches/<match_id>/sessions', methods=['POST'])
@require_auth
def create_session(match_id):
    """Create a session proposal."""
    user_id = request.user_id

    match, partner_id = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    data = request.get_json()
    sport = data.get('sport')
    day = data.get('day')
    start_hour = data.get('startHour')
    end_hour = data.get('endHour')
    location = data.get('location', '')

    if not sport or not day or start_hour is None or end_hour is None:
        return error_response('VALIDATION_ERROR', 'sport, day, startHour, and endHour are required')

    client = get_client()
    session_id = str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat() + 'Z'

    session_entity = Entity(client.key('Session', session_id))
    session_entity.update({
        'matchId': match_id,
        'proposerId': user_id,
        'responderId': partner_id,
        'sport': sport,
        'day': day,
        'startHour': start_hour,
        'endHour': end_hour,
        'location': location,
        'status': 'pending',
        'createdAt': created_at,
        'updatedAt': created_at,
    })
    client.put(session_entity)

    # Auto-create system message in chat
    proposer = get_user_by_id(user_id)
    proposer_name = proposer.get('displayName', 'Someone') if proposer else 'Someone'
    msg_id = str(uuid.uuid4())
    msg_entity = Entity(client.key('Message', msg_id))
    msg_entity.update({
        'matchId': match_id,
        'senderId': user_id,
        'text': f'{proposer_name} proposed a {sport} session on {day} from {start_hour}:00 to {end_hour}:00',
        'type': 'session_proposal',
        'metadata': {
            'sessionId': session_id,
            'sport': sport,
            'day': day,
            'startHour': start_hour,
            'endHour': end_hour,
            'location': location,
        },
        'readBy': [user_id],
        'createdAt': created_at,
    })
    client.put(msg_entity)

    return jsonify({
        'success': True,
        'data': {'session': session_to_dict(session_entity)}
    })


@match_bp.route('/matches/<match_id>/sessions/<session_id>', methods=['PUT'])
@require_auth
def update_session(match_id, session_id):
    """Accept or decline a session (responder only)."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    client = get_client()
    session_key = client.key('Session', session_id)
    session = client.get(session_key)

    if not session or session.get('matchId') != match_id:
        return error_response('SESSION_NOT_FOUND', 'Session not found', 404)

    if session.get('responderId') != user_id:
        return error_response('NOT_RESPONDER', 'Only the responder can accept/decline', 403)

    if session.get('status') != 'pending':
        return error_response('SESSION_NOT_PENDING', 'Session is no longer pending')

    data = request.get_json()
    action = data.get('action')  # "accept" or "decline"

    if action not in ('accept', 'decline'):
        return error_response('VALIDATION_ERROR', 'action must be "accept" or "decline"')

    now = datetime.utcnow().isoformat() + 'Z'
    session['status'] = 'accepted' if action == 'accept' else 'declined'
    session['updatedAt'] = now
    client.put(session)

    # Auto-create system message
    responder = get_user_by_id(user_id)
    responder_name = responder.get('displayName', 'Someone') if responder else 'Someone'
    verb = 'accepted' if action == 'accept' else 'declined'
    msg_id = str(uuid.uuid4())
    msg_entity = Entity(client.key('Message', msg_id))
    msg_entity.update({
        'matchId': match_id,
        'senderId': user_id,
        'text': f'{responder_name} {verb} the {session.get("sport")} session',
        'type': 'session_response',
        'metadata': {
            'sessionId': session_id,
            'action': action,
        },
        'readBy': [user_id],
        'createdAt': now,
    })
    client.put(msg_entity)

    return jsonify({
        'success': True,
        'data': {'session': session_to_dict(session)}
    })


@match_bp.route('/matches/<match_id>/sessions', methods=['GET'])
@require_auth
def get_sessions(match_id):
    """List sessions for a match."""
    user_id = request.user_id

    match, _ = get_match_for_user(match_id, user_id)
    if not match:
        return error_response('MATCH_NOT_FOUND', 'Match not found', 404)

    client = get_client()
    query = client.query(kind='Session')
    query.add_filter('matchId', '=', match_id)

    sessions = [session_to_dict(s) for s in query.fetch()]
    sessions.sort(key=lambda s: s.get('createdAt', ''), reverse=True)

    return jsonify({
        'success': True,
        'data': {'sessions': sessions}
    })


@match_bp.route('/sessions/upcoming', methods=['GET'])
@require_auth
def get_upcoming_sessions():
    """Get all accepted sessions for the current user."""
    user_id = request.user_id
    client = get_client()

    sessions = []
    for field in ['proposerId', 'responderId']:
        query = client.query(kind='Session')
        query.add_filter(field, '=', user_id)
        query.add_filter('status', '=', 'accepted')
        for s in query.fetch():
            sessions.append(session_to_dict(s))

    sessions.sort(key=lambda s: s.get('createdAt', ''), reverse=True)

    return jsonify({
        'success': True,
        'data': {'sessions': sessions}
    })
