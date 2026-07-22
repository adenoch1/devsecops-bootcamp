from flask import Flask, jsonify, render_template
from werkzeug.exceptions import HTTPException
import json
import logging
import os
import sys

app = Flask(__name__)

SERVICE_NAME = os.getenv("SERVICE_NAME", "devsecops-bootcamp")
APP_ENV = os.getenv("APP_ENV", "local")
GIT_SHA = os.getenv("GIT_SHA", "dev")


class JsonLogFormatter(logging.Formatter):
    """Structured JSON logs so CloudWatch metric filters can match on `level`."""

    def format(self, record):
        payload = {
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "service": SERVICE_NAME,
            "environment": APP_ENV,
            "git_sha": GIT_SHA,
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload)


_handler = logging.StreamHandler(sys.stdout)
_handler.setFormatter(JsonLogFormatter())
app.logger.handlers = [_handler]
app.logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


@app.errorhandler(Exception)
def handle_unexpected_error(exc):
    if isinstance(exc, HTTPException):
        return exc
    app.logger.error("Unhandled exception: %s", exc, exc_info=exc)
    return jsonify(status="error"), 500


@app.route("/health")
def health():
    return jsonify(status="ok"), 200

@app.route("/")
def index():
    return render_template("index.html")

if __name__ == "__main__":
    # Secure default: bind only to localhost
    host = os.getenv("FLASK_HOST", "127.0.0.1")

    # Container environments require binding to all interfaces
    if os.getenv("ENV") == "container":
        host = "0.0.0.0"  # nosec B104 - required to expose Flask from Docker container

    port = int(os.getenv("FLASK_PORT", "5000"))

    app.run(host=host, port=port)
