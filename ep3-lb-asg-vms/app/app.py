import math
import socket
import time

from fastapi import FastAPI

app = FastAPI()
hostname = socket.gethostname()


@app.get("/")
def index():
    return {"host": hostname, "status": "running"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/burn")
def burn():
    """Spike CPU for 45 seconds to trigger auto scaling policies."""
    end = time.time() + 45
    while time.time() < end:
        math.sqrt(12345678)
    return {"host": hostname, "message": "done", "duration_seconds": 45}
