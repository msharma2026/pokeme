import json
import logging
import re
import time

import anthropic

from config import Config

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level Anthropic client (avoids reconstructing on every call)
# ---------------------------------------------------------------------------
_anthropic_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    global _anthropic_client
    if _anthropic_client is None:
        _anthropic_client = anthropic.Anthropic(api_key=Config.ANTHROPIC_API_KEY)
    return _anthropic_client


# ---------------------------------------------------------------------------
# Per-viewer result cache  (5-minute TTL — background polls every 30s, so
# this reduces Claude calls by ~90% without meaningfully staling results)
# ---------------------------------------------------------------------------
_discover_cache: dict = {}  # viewer_id -> (timestamp, ranked_list)
_CACHE_TTL = 300  # seconds


# ---------------------------------------------------------------------------
# Claude AI recommendation
# ---------------------------------------------------------------------------

def _parse_sports(raw):
    """Parse sports from a list of dicts, Datastore entities, or a JSON string."""
    if not raw:
        return []
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except (ValueError, TypeError):
            return []
    if isinstance(raw, list):
        return [s for s in raw if hasattr(s, 'get')]
    return []


def _profile_summary(user, include_name: bool = True) -> dict:
    """Extract relevant profile fields for the AI prompt (no pictures)."""
    sports = _parse_sports(user.get('sports', []))
    sports_str = ', '.join(
        f"{s.get('sport', '?')} ({s.get('skillLevel', '?')})"
        for s in sports
    ) or 'None'

    availability = user.get('availability', {}) or {}
    avail_parts = []
    for day, slots in availability.items():
        if isinstance(slots, list) and slots:
            avail_parts.append(f"{day}:{','.join(slots)}")
    avail_str = ';'.join(avail_parts) or 'Not set'

    # Bio is capped at 150 chars — the front of a bio carries the most
    # signal; longer text only adds tokens without improving scores.
    bio = (user.get('bio') or '')[:150]

    summary: dict = {
        'collegeYear': user.get('collegeYear') or 'Not set',
        'major': user.get('major') or 'Not set',
        'bio': bio,
        'sports': sports_str,
        'availability': avail_str,
    }
    if include_name:
        summary['displayName'] = user.get('displayName', 'Unknown')
    return summary


def _build_prompt(viewer_summary: dict, candidate_summaries: list) -> str:
    """Build the Claude prompt for ranking candidates."""
    # Compact JSON (no indent) — removes ~30% of input tokens vs indent=2.
    # Candidates omit displayName; they are identified by their "index" field.
    candidates_json = json.dumps(candidate_summaries)
    viewer_json = json.dumps(viewer_summary)

    return f"""You are a matchmaking AI for a college sports app. Score compatibility between the viewer and each candidate for playing sports together.

VIEWER: {viewer_json}

CANDIDATES: {candidates_json}

Score each candidate on:
- Sports overlap & skill alignment (~55%)
- Availability overlap (~20%)
- College year proximity (~10%)
- Major/bio similarity (~15%)

Return a JSON array ONLY (no markdown). Each element: {{"id":<index>,"score":<0-100>,"breakdown":{{"sports":<0-100>,"availability":<0-100>,"collegeYear":<0-100>,"majorBio":<0-100>}}}}"""


def _generate_reasons(breakdown: dict, shared_sports: list | None = None) -> list[str]:
    """Generate human-readable reasons from a score breakdown dict."""
    reasons = []
    if shared_sports:
        reasons.append(f"Shared sports: {', '.join(shared_sports[:3])}")
    elif breakdown.get('sports', 0) >= 60:
        reasons.append('Compatible sports and skill levels')
    if breakdown.get('availability', 0) >= 40:
        reasons.append('Overlapping availability windows')
    if breakdown.get('collegeYear', 0) >= 65:
        reasons.append('Similar college year')
    if breakdown.get('majorBio', 0) >= 60:
        reasons.append('Similar academic background or interests')
    if not reasons:
        reasons.append('Recommended from overall profile compatibility')
    return reasons


def _call_claude(viewer, candidates):
    """Call Claude API to rank candidates. Returns list of recommendations or None on failure."""
    if not Config.ANTHROPIC_API_KEY:
        logger.warning('ANTHROPIC_API_KEY not set, falling back to heuristic')
        return None

    viewer_summary = _profile_summary(viewer, include_name=True)
    candidate_summaries = []
    for i, c in enumerate(candidates):
        summary = _profile_summary(c, include_name=False)
        summary['index'] = i
        candidate_summaries.append(summary)

    if not candidate_summaries:
        return []

    prompt = _build_prompt(viewer_summary, candidate_summaries)

    try:
        response = _get_client().messages.create(
            model='claude-haiku-4-5-20251001',
            max_tokens=4096,
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
        logger.warning(f'Claude API call failed: {type(e).__name__}: {e}')
        return None


def invalidate_viewer_cache(viewer_id: str):
    """Remove a viewer's cached discover results (e.g. after poke/match reset)."""
    _discover_cache.pop(viewer_id, None)


def rank_discover_candidates(viewer, candidates):
    """Rank candidates using Claude AI, with heuristic fallback."""
    if not candidates:
        return []

    viewer_id = viewer.key.name or str(viewer.key.id)

    # Return cached results if still fresh — background polls run every 30s
    # so this cuts Claude calls by ~90% while keeping results current.
    cached = _discover_cache.get(viewer_id)
    if cached:
        ts, result = cached
        if time.time() - ts < _CACHE_TTL:
            logger.info(f'Returning cached discover results for viewer {viewer_id}')
            return result

    ai_results = _call_claude(viewer, candidates)

    if ai_results is not None:
        # Build lookup by index — tolerates partial results from Claude
        ai_by_index = {}
        for r in ai_results:
            idx = r.get('id')
            if isinstance(idx, int) and 0 <= idx < len(candidates):
                ai_by_index[idx] = r

        if ai_by_index:
            logger.info(f'Claude AI scored {len(ai_by_index)}/{len(candidates)} candidates')
            ranked = []
            for i, candidate in enumerate(candidates):
                candidate_id = candidate.key.name or str(candidate.key.id)
                if i in ai_by_index:
                    ai = ai_by_index[i]
                    breakdown = ai.get('breakdown', {
                        'sports': 50, 'availability': 50,
                        'collegeYear': 50, 'majorBio': 50,
                    })
                    recommendation = {
                        'score': max(0, min(100, ai.get('score', 50))),
                        'reasons': _generate_reasons(breakdown),
                        'breakdown': breakdown,
                        'rankedBy': 'claude',
                    }
                else:
                    recommendation = _heuristic_score(viewer, candidate)
                    recommendation['rankedBy'] = 'heuristic'

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

            _discover_cache[viewer_id] = (time.time(), ranked)
            return ranked

    # Fallback to heuristic
    logger.warning('Claude AI unavailable or returned no results, using heuristic fallback')
    result = _rank_heuristic(viewer, candidates)
    _discover_cache[viewer_id] = (time.time(), result)
    return result


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
    for entry in _parse_sports(user.get('sports', [])):
        if not hasattr(entry, 'get'):
            continue
        sport_name = _normalized_str(entry.get('sport'))
        if not sport_name:
            continue
        skill = _normalized_str(entry.get('skillLevel'))
        sports[sport_name] = SKILL_LEVEL_SCORES.get(skill, 2)
    return sports


def _availability_slots(user):
    availability = user.get('availability', {}) or {}
    if isinstance(availability, str):
        try:
            availability = json.loads(availability)
        except (ValueError, TypeError):
            availability = {}
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

    breakdown = {
        'sports': round(sports_score * 100, 2),
        'availability': round(avail_score * 100, 2),
        'collegeYear': round(year_score * 100, 2),
        'majorBio': round(major_bio_score * 100, 2),
    }

    return {
        'score': round(total * 100, 2),
        'reasons': _generate_reasons(breakdown, shared_sports=sorted(shared_sports)[:3] if shared_sports else None),
        'breakdown': breakdown,
    }


def score_user_pair(viewer, candidate):
    """Public wrapper around the heuristic scorer for a single viewer-candidate pair."""
    return _heuristic_score(viewer, candidate)


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
