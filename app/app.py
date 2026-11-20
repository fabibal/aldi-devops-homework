import os
from flask import Flask, jsonify, request

app = Flask(__name__)
config = {}


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/version")
def version():
    return jsonify(version="1.0.0")


@app.get("/env")
def env():
    return jsonify(environment=os.environ.get("ENVIRONMENT"))


@app.post("/config")
def set_config():
    data = request.get_json(silent=True) or {}
    if "name" not in data or "value" not in data:
        return jsonify(error="name and value are required"), 400
    config[data["name"]] = data["value"]
    return jsonify(name=data["name"], value=data["value"])


@app.get("/config/<name>")
def get_config(name):
    if name not in config:
        return jsonify(error="not found"), 404
    return jsonify(name=name, value=config[name])


@app.delete("/config/<name>")
def delete_config(name):
    if name not in config:
        return jsonify(deleted=False), 404
    del config[name]
    return jsonify(deleted=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
