#!/bin/bash
# One-shot deploy: if the remote has new commits or the container is missing,
# pull and restart the container.
# Intended to be run from cron every minute.
set -euo pipefail

cd "$(dirname "$0")"

git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

if ! docker info >/dev/null 2>&1; then
  echo "$(date): cannot access Docker. Run with sudo or add this user to the docker group." >&2
  exit 1
fi

CONTAINER_ID=$(docker ps -aq --filter name='^/marimo$')

if [ "$LOCAL" = "$REMOTE" ] && [ -n "$CONTAINER_ID" ]; then
  RUNNING=$(docker inspect -f '{{.State.Running}}' marimo 2>/dev/null || echo false)
  [ "$RUNNING" = "true" ] && exit 0
fi

echo "$(date): new commits ($LOCAL -> $REMOTE), deploying..."
if [ "$LOCAL" != "$REMOTE" ]; then
  git pull --ff-only
else
  echo "$(date): no new commits, but marimo is missing or stopped; redeploying..."
fi
docker build -t marimo-dashboards .
docker stop marimo 2>/dev/null || true
docker rm marimo 2>/dev/null || true
docker run -d --name marimo --restart unless-stopped -p 8000:8000 marimo-dashboards
echo "$(date): deploy complete."
