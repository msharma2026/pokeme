import json
import logging
import re

import anthropic

from config import Config

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Claude AI recommendation
# ---------------------------------------------------------------------------

def _profile_summary(user):
    """Extract relevant profile fields for the AI prompt (no pictures)."""
    sports = user.get('sports', []) or []
    sports_str = ', '.join(
        f"{s.get('sport', '?')} ({s.get('skillLevel', '?')})"
        for s in sports if isinstance(s, dict)
    ) or 'None'

    availability = user.get('availability', {}) or {}
    avail_parts = []
    for day, slots in availability.items():
        if isinstance(slots, list) and slots:
            avail_parts.append(f"{day}: {', '.join(slots)}")
    avail_str = '; '.join(avail_parts) or 'Not set'

    return {
        'displayName': user.get('displayName', 'Unknown'),
        'collegeYear': user.get('collegeYear') or 'Not set',
        'major': user.get('major') or 'Not set',
        'bio': user.get('bio') or '',
        'sports': sports_str,
        'availability': avail_str,
    }


def _build_prompt(viewer_summary, candidate_summaries):
    """Build the Claude prompt for ranking candidates."""
    candidates_json = json.dumps(candidate_summaries, indent=2)
    viewer_json = json.dumps(viewer_summary, indent=2)

    return f"""You are a matchmaking AI for a college sports app called PokeMe. Your job is to score how compatible each candidate is with the viewer for playing sports together.

VIEWER PROFILE:
{viewer_json}

CANDIDATE PROFILES:
{candidates_json}

For each candidate, evaluate compatibility based on:
- Sports overlap and skill level alignment (most important ~55%)
- Availability overlap - can they actually meet up? (~20%)
- College year proximity (~10%)
- Shared interests from major/bio (~15%)

Return a JSON array (no markdown, no explanation) where each element has:
- "id": the candidate's index (0-based)
- "score": integer 0-100 (overall compatibility)
- "reasons": array of 1-3 short human-readable reasons (e.g. "Both play volleyball at similar levels", "Free on Saturday afternoons")
- "breakdown": object with "sports", "availability", "collegeYear", "majorBio" each 0-100

Example response format:
[{{"id": 0, "score": 82, "reasons": ["Both play tennis at intermediate level", "Overlapping Saturday availability"], "breakdown": {{"sports": 90, "availability": 75, "collegeYear": 80, "majorBio": 60}}}}]

Return ONLY the JSON array, nothing else."""


def _call_claude(viewer, candidates):
    """Call Claude API to rank candidates. Returns list of recommendations or None on failure."""
    api_key = Config.ANTHROPIC_API_KEY
    if not api_key:
        logger.warning('ANTHROPIC_API_KEY not set, falling back to heuristic')
        return None

    viewer_summary = _profile_summary(viewer)
    candidate_summaries = []
    for i, c in enumerate(candidates):
        summary = _profile_summary(c)
        summary['index'] = i
        candidate_summaries.append(summary)

    if not candidate_summaries:
        return []

    prompt = _build_prompt(viewer_summary, candidate_summaries)

    try:
        client = anthropic.Anthropic(api_key=api_key)
        response = client.messages.create(
            model='claude-haiku-4-5-20251001',
            max_tokens=2048,
            messages=[{'role': 'user', 'content': prompt}],
        )

        text = response.content[0].text.strip()
        # Strip markdown code fences if present
        if text.startswith('```'):
            text = re.sub(r'^```\w*\n?', '', text)
            text = re.sub(r'\n?```$', '', text)
            text = text.strip()

        results = json.loads(text)
        if not isinstance(results, list):
            logger.warning('Claude returned non-list response, falling back')
            return None

        return results

    except Exception as e:
        logger.warning(f'Claude API call failed: {e}, falling back to heuristic')
        return None


def rank_discover_candidates(viewer, candidates):
    """Rank candidates using Claude AI, with heuristic fallback."""
    ai_results = _call_claude(viewer, candidates)

    if ai_results is not None and len(ai_results) == len(candidates):
        # Build lookup by index
        ai_by_index = {}
        for r in ai_results:
            idx = r.get('id')
            if isinstance(idx, int) and 0 <= idx < len(candidates):
                ai_by_index[idx] = r

        ranked = []
        for i, candidate in enumerate(candidates):
            candidate_id = candidate.key.name or str(candidate.key.id)
            if i in ai_by_index:
                ai = ai_by_index[i]
                recommendation = {
                    'score': max(0, min(100, ai.get('score', 50))),
                    'reasons': ai.get('reasons', ['AI-recommended match']),
                    'breakdown': ai.get('breakdown', {
                        'sports': 50, 'availability': 50,
                        'collegeYear': 50, 'majorBio': 50,
                    }),
                }
            else:
                recommendation = _heuristic_score(viewer, candidate)

            ranked.append({
                'candidateId': candidate_id,
                'candidate': candidate,
                'recommendation': recommendation,
            })

        ranked.sort(key=lambda item: (
            -item['recommendation']['score'],
            item['candidate'].get('displayName', '').strip().lower(),
            item['candidateId'],
        ))
        return ranked

    # Fallback to heuristic
    logger.info('Using heuristic fallback for recommendations')
    return _rank_heuristic(viewer, candidates)


# ---------------------------------------------------------------------------
# Heuristic fallback (original scoring logic)
# ---------------------------------------------------------------------------

SKILL_LEVEL_SCORES = {
    'beginner': 1,
    'intermediate': 2,
    'advanced': 3,
}

COLLEGE_YEAR_ORDER = [
    'freshman', 'sophomore', 'junior', 'senior', 'graduate',
]

STOPWORDS = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'for', 'from', 'i', 'in', 'is',
    'it', 'my', 'of', 'on', 'or', 'our', 'that', 'the', 'their', 'to', 'we',
    'with', 'you', 'your',
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
    return len(set_a & set_b) / len(union)


def _heuristic_score(viewer, candidate):
    """Score a single viewer-candidate pair using the heuristic formula."""
    viewer_sports = _sport_map(viewer)
    candidate_sports = _sport_map(candidate)

    # Sports
    shared_sports = set(viewer_sports.keys()) & set(candidate_sports.keys())
    if viewer_sports and candidate_sports and shared_sports:
        coverage = len(shared_sports) / max(len(viewer_sports), len(candidate_sports))
        skill_alignment = sum(
            max(0.0, 1.0 - 0.25 * abs(viewer_sports[s] - candidate_sports[s]))
            for s in shared_sports
        ) / len(shared_sports)
        sports_score = min(1.0, 0.7 * coverage + 0.3 * skill_alignment)
    else:
        sports_score = 0.0

    # Availability
    avail_score = _jaccard_similarity(_availability_slots(viewer), _availability_slots(candidate))

    # College year
    vy = _normalized_str(viewer.get('collegeYear'))
    cy = _normalized_str(candidate.get('collegeYear'))
    if vy in COLLEGE_YEAR_ORDER and cy in COLLEGE_YEAR_ORDER:
        year_score = max(0.0, 1.0 - 0.35 * abs(
            COLLEGE_YEAR_ORDER.index(vy) - COLLEGE_YEAR_ORDER.index(cy)
        ))
    else:
        year_score = 0.0

    # Major / bio
    vm = _normalized_str(viewer.get('major'))
    cm = _normalized_str(candidate.get('major'))
    major_match = 1.0 if vm and vm == cm else 0.0
    vt = _tokenize_text(f"{viewer.get('major', '')} {viewer.get('bio', '')}")
    ct = _tokenize_text(f"{candidate.get('major', '')} {candidate.get('bio', '')}")
    text_sim = _jaccard_similarity(vt, ct)
    major_bio_score = min(1.0, 0.6 * major_match + 0.4 * text_sim)

    total = (
        sports_score * COMPONENT_WEIGHTS['sports']
        + avail_score * COMPONENT_WEIGHTS['availability']
        + year_score * COMPONENT_WEIGHTS['collegeYear']
        + major_bio_score * COMPONENT_WEIGHTS['majorBio']
    )

    reasons = []
    if shared_sports:
        reasons.append(f"Shared sports: {', '.join(sorted(shared_sports)[:3])}")
    if _availability_slots(viewer) & _availability_slots(candidate):
        reasons.append('Overlapping availability windows')
    if year_score >= 0.65:
        reasons.append('Similar college year')
    if major_match:
        reasons.append('Same major')
    if not reasons:
        reasons.append('Recommended from overall profile compatibility')

    return {
        'score': round(total * 100, 2),
        'reasons': reasons,
        'breakdown': {
            'sports': round(sports_score * 100, 2),
            'availability': round(avail_score * 100, 2),
            'collegeYear': round(year_score * 100, 2),
            'majorBio': round(major_bio_score * 100, 2),
        },
    }


def _rank_heuristic(viewer, candidates):
    """Rank candidates using the heuristic formula (fallback)."""
    ranked = []
    for candidate in candidates:
        candidate_id = candidate.key.name or str(candidate.key.id)
        ranked.append({
            'candidateId': candidate_id,
            'candidate': candidate,
            'recommendation': _heuristic_score(viewer, candidate),
        })
    ranked.sort(key=lambda item: (
        -item['recommendation']['score'],
        item['candidate'].get('displayName', '').strip().lower(),
        item['candidateId'],
    ))
    return ranked
