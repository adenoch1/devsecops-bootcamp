from flask import Flask, jsonify, render_template
import os

app = Flask(__name__)

# Build/deploy metadata injected by CI as env vars (see task definition / workflow).
# Defaults keep local runs working without any setup.
BUILD_INFO = {
    "service": os.getenv("SERVICE_NAME", "devsecops-bootcamp"),
    "environment": os.getenv("APP_ENV", "local"),
    "git_sha": os.getenv("GIT_SHA", "dev"),
    "image_tag": os.getenv("IMAGE_TAG", "local"),
    "built_at": os.getenv("BUILD_TIME", "unknown"),
}


@app.route("/health")
def health():
    return jsonify(status="ok"), 200


@app.route("/version")
def version():
    return jsonify(BUILD_INFO), 200


@app.route("/")
def index():
    return render_template("index.html", build=BUILD_INFO)


if __name__ == "__main__":
    # Secure default: bind only to localhost
    host = os.getenv("FLASK_HOST", "127.0.0.1")

    # Container environments require binding to all interfaces
    if os.getenv("ENV") == "container":
        host = "0.0.0.0"  # nosec B104 - required to expose Flask from Docker container

    port = int(os.getenv("FLASK_PORT", "5000"))

    app.run(host=host, port=port)
