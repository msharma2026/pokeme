from flask import Blueprint, request, jsonify
from datetime import datetime
import uuid

from db import get_client, Entity
from models import meetup_to_dict
from middleware import require_auth
from auth import get_user_by_id

meetup_bp = Blueprint('meetup', __name__)


def error_response(code, message, status=400):
    return jsonify({
        'success': False,
        'error': {'code': code, 'message': message}
    }), status


@meetup_bp.route('/meetups', methods=['POST'])
@require_auth
def create_meetup():
    """Create a new meetup."""
    user_id = request.user_id
    user = get_user_by_id(user_id)
    if not user:
        return error_response('USER_NOT_FOUND', 'User not found', 404)

    data = request.get_json()
    sport = data.get('sport')
    title = data.get('title')
    date = data.get('date')
    time = data.get('time')

    if not sport or not title or not date or not time:
        return error_response('VALIDATION_ERROR', 'sport, title, date, and time are required')

    client = get_client()
    meetup_id = str(uuid.uuid4())
    created_at = datetime.utcnow().isoformat() + 'Z'

    entity = Entity(client.key('Meetup', meetup_id))
    entity.update({
        'hostId': user_id,
        'hostName': user.get('displayName', 'Unknown'),
        'sport': sport,
        'title': title,
        'description': data.get('description', ''),
        'date': date,
        'time': time,
        'location': data.get('location', ''),
        'skillLevels': data.get('skillLevels', []),
        'playerLimit': data.get('playerLimit', 10),
        'participants': [user_id],
        'status': 'active',
        'createdAt': created_at,
    })
    client.put(entity)

    return jsonify({
        'success': True,
        'data': {'meetup': meetup_to_dict(entity)}
    }), 201


@meetup_bp.route('/meetups', methods=['GET'])
@require_auth
def list_meetups():
    """List active future meetups, optional sport and date filters."""
    sport_filter = request.args.get('sport')
    date_filter = request.args.get('date')

    client = get_client()
    query = client.query(kind='Meetup')
    query.add_filter('status', '=', 'active')

    meetups = []
    for entity in query.fetch():
        if sport_filter and entity.get('sport', '').lower() != sport_filter.lower():
            continue
        if date_filter and entity.get('date') != date_filter:
            continue
        meetups.append(meetup_to_dict(entity))

    meetups.sort(key=lambda m: m.get('date', '') + m.get('time', ''))

    return jsonify({
        'success': True,
        'data': {'meetups': meetups}
    })


@meetup_bp.route('/meetups/mine', methods=['GET'])
@require_auth
def my_meetups():
    """Get user's hosted and joined meetups."""
    user_id = request.user_id
    client = get_client()

    query = client.query(kind='Meetup')
    query.add_filter('status', '=', 'active')

    meetups = []
    for entity in query.fetch():
        participants = entity.get('participants', [])
        if user_id in participants or entity.get('hostId') == user_id:
            meetups.append(meetup_to_dict(entity))

    meetups.sort(key=lambda m: m.get('date', '') + m.get('time', ''))

    return jsonify({
        'success': True,
        'data': {'meetups': meetups}
    })


@meetup_bp.route('/meetups/<meetup_id>/join', methods=['POST'])
@require_auth
def join_meetup(meetup_id):
    """Join a meetup."""
    user_id = request.user_id
    client = get_client()

    key = client.key('Meetup', meetup_id)
    meetup = client.get(key)

    if not meetup or meetup.get('status') != 'active':
        return error_response('MEETUP_NOT_FOUND', 'Meetup not found', 404)

    participants = meetup.get('participants', [])
    if user_id in participants:
        return error_response('ALREADY_JOINED', 'You already joined this meetup')

    player_limit = meetup.get('playerLimit', 10)
    if len(participants) >= player_limit:
        return error_response('MEETUP_FULL', 'This meetup is full')

    participants.append(user_id)
    meetup['participants'] = participants
    client.put(meetup)

    return jsonify({
        'success': True,
        'data': {'meetup': meetup_to_dict(meetup)}
    })


@meetup_bp.route('/meetups/<meetup_id>/leave', methods=['POST'])
@require_auth
def leave_meetup(meetup_id):
    """Leave a meetup (not host)."""
    user_id = request.user_id
    client = get_client()

    key = client.key('Meetup', meetup_id)
    meetup = client.get(key)

    if not meetup or meetup.get('status') != 'active':
        return error_response('MEETUP_NOT_FOUND', 'Meetup not found', 404)

    if meetup.get('hostId') == user_id:
        return error_response('HOST_CANNOT_LEAVE', 'Host cannot leave. Cancel the meetup instead.')

    participants = meetup.get('participants', [])
    if user_id not in participants:
        return error_response('NOT_JOINED', 'You are not in this meetup')

    participants.remove(user_id)
    meetup['participants'] = participants
    client.put(meetup)

    return jsonify({
        'success': True,
        'data': {'meetup': meetup_to_dict(meetup)}
    })


@meetup_bp.route('/meetups/<meetup_id>', methods=['DELETE'])
@require_auth
def cancel_meetup(meetup_id):
    """Cancel a meetup (host only)."""
    user_id = request.user_id
    client = get_client()

    key = client.key('Meetup', meetup_id)
    meetup = client.get(key)

    if not meetup:
        return error_response('MEETUP_NOT_FOUND', 'Meetup not found', 404)

    if meetup.get('hostId') != user_id:
        return error_response('NOT_HOST', 'Only the host can cancel', 403)

    meetup['status'] = 'cancelled'
    client.put(meetup)

    return jsonify({
        'success': True,
        'data': {'message': 'Meetup cancelled'}
    })
