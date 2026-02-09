from datetime import datetime
from config import Config


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
