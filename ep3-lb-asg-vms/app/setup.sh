#!/bin/bash
set -euo pipefail

mkdir -p /app

python3 -m venv /app/venv
/app/venv/bin/pip install -r /app/requirements.txt

systemctl daemon-reload
systemctl enable app
systemctl start app
