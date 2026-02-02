from datetime import datetime
from config import Config


def user_to_dict(entity, include_password=False):
    """Convert a Datastore user entity to a dictionary."""
    if entity is None:
        return None

    result = {
        'id': entity.key.name or str(entity.key.id),
        'email': entity.get('email'),
        'displayName': entity.get('displayName'),
        'major': entity.get('major'),
        'socialPoints': entity.get('socialPoints', Config.INITIAL_SOCIAL_POINTS),
        'createdAt': entity.get('createdAt'),
    }

    if include_password:
        result['passwordHash'] = entity.get('passwordHash')

    return result


def match_to_dict(entity, partner=None):
    """Convert a Datastore match entity to a dictionary for API response."""
    if entity is None:
        return None

    result = {
        'id': entity.key.name or str(entity.key.id),
        'date': entity.get('date'),
        'status': entity.get('status'),
        'createdAt': entity.get('createdAt'),
    }

    if partner:
        result['partnerId'] = partner.get('id')
        result['partnerName'] = partner.get('displayName')
        result['partnerMajor'] = partner.get('major')

    return result
