#!/bin/bash
# One-shot deploy: if the remote has new commits, pull and restart the container.
# Intended to be run from cron every minute.
set -euo pipefail

cd "$(dirname "$0")"

git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

[ "$LOCAL" = "$REMOTE" ] && exit 0

echo "$(date): new commits ($LOCAL -> $REMOTE), deploying..."
git pull --ff-only
docker build -t marimo-dashboards .
docker stop marimo 2>/dev/null || true
docker rm marimo 2>/dev/null || true
docker run -d --name marimo --restart unless-stopped -p 8000:8000 marimo-dashboards
echo "$(date): deploy complete."
