from datetime import datetime
from config import Config

# Hour ranges for availability shortcuts
AVAILABILITY_SHORTCUTS = {
    'Morning': list(range(6, 12)),    # 6:00 - 11:00
    'Afternoon': list(range(12, 17)), # 12:00 - 16:00
    'Evening': list(range(17, 22)),   # 17:00 - 21:00
}


def expand_availability(availability):
    """Expand availability shortcuts to hour sets.

    Input: {"Monday": ["Morning", "14:00", "15:00"], ...}
    Output: {"Monday": {6,7,8,9,10,11,14,15}, ...}
    """
    expanded = {}
    for day, slots in (availability or {}).items():
        hours = set()
        for slot in slots:
            if slot in AVAILABILITY_SHORTCUTS:
                hours.update(AVAILABILITY_SHORTCUTS[slot])
            else:
                # Parse "HH:00" format
                try:
                    hour = int(slot.split(':')[0])
                    if 0 <= hour <= 23:
                        hours.add(hour)
                except (ValueError, IndexError):
                    pass
        if hours:
            expanded[day] = hours
    return expanded


def session_to_dict(entity):
    """Convert a Datastore Session entity to a dictionary."""
    if entity is None:
        return None
    return {
        'id': entity.key.name or str(entity.key.id),
        'matchId': entity.get('matchId'),
        'proposerId': entity.get('proposerId'),
        'responderId': entity.get('responderId'),
        'sport': entity.get('sport'),
        'day': entity.get('day'),
        'startHour': entity.get('startHour'),
        'endHour': entity.get('endHour'),
        'location': entity.get('location'),
        'status': entity.get('status'),
        'createdAt': entity.get('createdAt'),
        'updatedAt': entity.get('updatedAt'),
    }


def meetup_to_dict(entity):
    """Convert a Datastore Meetup entity to a dictionary."""
    if entity is None:
        return None
    return {
        'id': entity.key.name or str(entity.key.id),
        'hostId': entity.get('hostId'),
        'hostName': entity.get('hostName'),
        'sport': entity.get('sport'),
        'title': entity.get('title'),
        'description': entity.get('description'),
        'date': entity.get('date'),
        'time': entity.get('time'),
        'location': entity.get('location'),
        'skillLevels': entity.get('skillLevels', []),
        'playerLimit': entity.get('playerLimit'),
        'participants': entity.get('participants', []),
        'status': entity.get('status', 'active'),
        'createdAt': entity.get('createdAt'),
    }


def user_to_dict(entity, include_password=False):
    """Convert a Datastore user entity to a dictionary."""
    if entity is None:
        return None

    result = {
        'id': entity.key.name or str(entity.key.id),
        'email': entity.get('email'),
        'phone': entity.get('phone'),
        'displayName': entity.get('displayName'),
        'major': entity.get('major'),
        'bio': entity.get('bio'),
        'profilePicture': entity.get('profilePicture'),
        'socials': entity.get('socials', {}),
        'sports': entity.get('sports', []),
        'collegeYear': entity.get('collegeYear'),
        'availability': entity.get('availability', {}),
        'createdAt': entity.get('createdAt'),
    }

    if include_password:
        result['passwordHash'] = entity.get('passwordHash')

    return result
