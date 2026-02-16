from recommendation import score_user_pair, rank_discover_candidates


class FakeKey:
    def __init__(self, name):
        self.name = name
        self.id = None


class FakeEntity(dict):
    def __init__(self, entity_id, **kwargs):
        super().__init__(**kwargs)
        self.key = FakeKey(entity_id)


def test_score_user_pair_rewards_shared_profile_signals():
    viewer = {
        'major': 'Computer Science',
        'bio': 'I like pickup basketball and evening runs',
        'sports': [
            {'sport': 'Basketball', 'skillLevel': 'Intermediate'},
            {'sport': 'Running', 'skillLevel': 'Beginner'},
        ],
        'collegeYear': 'Junior',
        'availability': {
            'Monday': ['Evening'],
            'Wednesday': ['Evening'],
        }
    }

    strong_candidate = {
        'major': 'Computer Science',
        'bio': 'Basketball and running are my favorites too',
        'sports': [
            {'sport': 'Basketball', 'skillLevel': 'Advanced'},
            {'sport': 'Running', 'skillLevel': 'Intermediate'},
        ],
        'collegeYear': 'Senior',
        'availability': {
            'Monday': ['Evening'],
            'Friday': ['Morning'],
        }
    }

    weak_candidate = {
        'major': 'Design',
        'bio': 'Mostly swimming and yoga',
        'sports': [
            {'sport': 'Swimming', 'skillLevel': 'Advanced'},
        ],
        'collegeYear': 'Freshman',
        'availability': {
            'Tuesday': ['Morning'],
        }
    }

    strong_score = score_user_pair(viewer, strong_candidate)
    weak_score = score_user_pair(viewer, weak_candidate)

    assert strong_score['score'] > weak_score['score']
    assert any('Shared sports' in reason for reason in strong_score['reasons'])


def test_rank_discover_candidates_orders_highest_score_first():
    viewer = {
        'major': 'Economics',
        'bio': 'Soccer and weekend games',
        'sports': [{'sport': 'Soccer', 'skillLevel': 'Intermediate'}],
        'collegeYear': 'Sophomore',
        'availability': {'Saturday': ['Morning']}
    }

    low_match = FakeEntity(
        'u-low',
        displayName='Low Match',
        major='Biology',
        bio='Swimming only',
        sports=[{'sport': 'Swimming', 'skillLevel': 'Beginner'}],
        collegeYear='Graduate',
        availability={'Tuesday': ['Evening']},
    )
    high_match = FakeEntity(
        'u-high',
        displayName='High Match',
        major='Economics',
        bio='Soccer on weekends',
        sports=[{'sport': 'Soccer', 'skillLevel': 'Advanced'}],
        collegeYear='Junior',
        availability={'Saturday': ['Morning']},
    )

    ranked = rank_discover_candidates(viewer, [low_match, high_match])

    assert ranked[0]['candidateId'] == 'u-high'
    assert ranked[0]['recommendation']['score'] >= ranked[1]['recommendation']['score']
