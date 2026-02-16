import re


SKILL_LEVEL_SCORES = {
    'beginner': 1,
    'intermediate': 2,
    'advanced': 3,
}

COLLEGE_YEAR_ORDER = [
    'freshman',
    'sophomore',
    'junior',
    'senior',
    'graduate',
]

STOPWORDS = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'for', 'from', 'i', 'in', 'is',
    'it', 'my', 'of', 'on', 'or', 'our', 'that', 'the', 'their', 'to', 'we',
    'with', 'you', 'your'
}

COMPONENT_WEIGHTS = {
    'sports': 0.55,
    'availability': 0.20,
    'collegeYear': 0.10,
    'majorBio': 0.15,
}


def _normalized_str(value):
    if not isinstance(value, str):
        return ''
    return value.strip().lower()


def _tokenize_text(text):
    if not isinstance(text, str):
        return set()
    raw_tokens = re.findall(r"[a-z0-9']+", text.lower())
    return {t for t in raw_tokens if len(t) > 1 and t not in STOPWORDS}


def _sport_map(user):
    sports = {}
    for entry in user.get('sports', []) or []:
        if not isinstance(entry, dict):
            continue
        sport_name = _normalized_str(entry.get('sport'))
        if not sport_name:
            continue
        skill = _normalized_str(entry.get('skillLevel'))
        sports[sport_name] = SKILL_LEVEL_SCORES.get(skill, 2)
    return sports


def _availability_slots(user):
    availability = user.get('availability', {}) or {}
    slots = set()

    if not isinstance(availability, dict):
        return slots

    for day, day_slots in availability.items():
        day_key = _normalized_str(day)
        if not day_key or not isinstance(day_slots, list):
            continue
        for slot in day_slots:
            if not isinstance(slot, str):
                continue
            slot_key = _normalized_str(slot)
            if slot_key:
                slots.add(f'{day_key}:{slot_key}')

    return slots


def _jaccard_similarity(set_a, set_b):
    if not set_a or not set_b:
        return 0.0
    union = set_a | set_b
    if not union:
        return 0.0
    intersection = set_a & set_b
    return len(intersection) / len(union)


def _sports_similarity(viewer, candidate):
    viewer_sports = _sport_map(viewer)
    candidate_sports = _sport_map(candidate)

    if not viewer_sports or not candidate_sports:
        return 0.0, []

    shared_sports = set(viewer_sports.keys()) & set(candidate_sports.keys())
    if not shared_sports:
        return 0.0, []

    shared_count = len(shared_sports)
    coverage = shared_count / max(len(viewer_sports), len(candidate_sports))

    skill_alignment = 0.0
    for sport in shared_sports:
        skill_gap = abs(viewer_sports[sport] - candidate_sports[sport])
        skill_alignment += max(0.0, 1.0 - (0.25 * skill_gap))
    skill_alignment /= shared_count

    score = (0.7 * coverage) + (0.3 * skill_alignment)
    ordered_shared = sorted(shared_sports)
    return min(1.0, score), ordered_shared


def _availability_similarity(viewer, candidate):
    viewer_slots = _availability_slots(viewer)
    candidate_slots = _availability_slots(candidate)
    score = _jaccard_similarity(viewer_slots, candidate_slots)
    overlaps = sorted(viewer_slots & candidate_slots)
    return score, overlaps


def _college_year_similarity(viewer, candidate):
    viewer_year = _normalized_str(viewer.get('collegeYear'))
    candidate_year = _normalized_str(candidate.get('collegeYear'))
    if not viewer_year or not candidate_year:
        return 0.0
    if viewer_year not in COLLEGE_YEAR_ORDER or candidate_year not in COLLEGE_YEAR_ORDER:
        return 0.0

    year_distance = abs(COLLEGE_YEAR_ORDER.index(viewer_year) - COLLEGE_YEAR_ORDER.index(candidate_year))
    return max(0.0, 1.0 - (0.35 * year_distance))


def _major_bio_similarity(viewer, candidate):
    viewer_major = _normalized_str(viewer.get('major'))
    candidate_major = _normalized_str(candidate.get('major'))

    major_match = 1.0 if viewer_major and viewer_major == candidate_major else 0.0

    viewer_text = f"{viewer.get('major', '')} {viewer.get('bio', '')}".strip()
    candidate_text = f"{candidate.get('major', '')} {candidate.get('bio', '')}".strip()
    viewer_tokens = _tokenize_text(viewer_text)
    candidate_tokens = _tokenize_text(candidate_text)

    text_similarity = _jaccard_similarity(viewer_tokens, candidate_tokens)
    token_overlap = sorted(viewer_tokens & candidate_tokens)

    score = min(1.0, (0.6 * major_match) + (0.4 * text_similarity))
    return score, bool(major_match), token_overlap


def score_user_pair(viewer, candidate):
    sports_score, shared_sports = _sports_similarity(viewer, candidate)
    availability_score, overlapping_slots = _availability_similarity(viewer, candidate)
    year_score = _college_year_similarity(viewer, candidate)
    major_bio_score, major_match, token_overlap = _major_bio_similarity(viewer, candidate)

    weighted_total = (
        (sports_score * COMPONENT_WEIGHTS['sports']) +
        (availability_score * COMPONENT_WEIGHTS['availability']) +
        (year_score * COMPONENT_WEIGHTS['collegeYear']) +
        (major_bio_score * COMPONENT_WEIGHTS['majorBio'])
    )
    final_score = round(weighted_total * 100, 2)

    reasons = []
    if shared_sports:
        reasons.append(f"Shared sports: {', '.join(shared_sports[:3])}")
    if overlapping_slots:
        reasons.append('Overlapping availability windows')
    if year_score >= 0.65:
        reasons.append('Similar college year')
    if major_match:
        reasons.append('Same major')
    elif token_overlap:
        reasons.append(f"Common interests: {', '.join(token_overlap[:3])}")
    if not reasons:
        reasons.append('Recommended from overall profile compatibility')

    return {
        'score': final_score,
        'reasons': reasons,
        'breakdown': {
            'sports': round(sports_score * 100, 2),
            'availability': round(availability_score * 100, 2),
            'collegeYear': round(year_score * 100, 2),
            'majorBio': round(major_bio_score * 100, 2),
        }
    }


def rank_discover_candidates(viewer, candidates):
    ranked = []
    for candidate in candidates:
        recommendation = score_user_pair(viewer, candidate)
        candidate_id = candidate.key.name or str(candidate.key.id)
        ranked.append({
            'candidateId': candidate_id,
            'candidate': candidate,
            'recommendation': recommendation
        })

    ranked.sort(
        key=lambda item: (
            -item['recommendation']['score'],
            _normalized_str(item['candidate'].get('displayName')),
            item['candidateId'],
        )
    )

    return ranked
