from flask import Flask, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# Import routes
from auth import auth_bp
from match import match_bp
from phone_auth import phone_auth_bp
from meetup import meetup_bp

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(match_bp, url_prefix='/api')
app.register_blueprint(phone_auth_bp, url_prefix='/api/phone')
app.register_blueprint(meetup_bp, url_prefix='/api')


@app.route('/api/health')
def health_check():
    from datetime import datetime
    return jsonify({
        'success': True,
        'data': {
            'status': 'ok',
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }
    })


@app.errorhandler(Exception)
def handle_exception(e):
    return jsonify({
        'success': False,
        'error': {
            'code': 'INTERNAL_ERROR',
            'message': str(e)
        }
    }), 500


@app.errorhandler(404)
def not_found(e):
    return jsonify({
        'success': False,
        'error': {
            'code': 'NOT_FOUND',
            'message': 'Endpoint not found'
        }
    }), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
