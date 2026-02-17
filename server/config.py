import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    JWT_SECRET = os.environ.get('JWT_SECRET', 'dev-secret-key')
    JWT_EXPIRATION_DAYS = 7
    INITIAL_SOCIAL_POINTS = 100
    TIMEZONE = 'America/Los_Angeles'  # Pacific Time for UC Davis
    ANTHROPIC_API_KEY = os.environ.get('ANTHROPIC_API_KEY')
