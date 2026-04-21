#!/bin/bash
# Polls the git repo every 30 seconds. On new commits (after git pull),
# rebuilds the Docker image and restarts the container.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "$(date): Watching for changes in $REPO_DIR..."

while true; do
    sleep 30

    git fetch origin 2>/dev/null || continue

    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse @{u} 2>/dev/null) || continue

    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "$(date): New commits detected ($LOCAL -> $REMOTE), pulling..."
        git pull --ff-only || { echo "Pull failed, skipping rebuild"; continue; }
        echo "$(date): Rebuilding Docker image..."
        docker build -t marimo-dashboards . || { echo "Build failed, skipping restart"; continue; }
        echo "$(date): Restarting container..."
        docker stop marimo 2>/dev/null || true
        docker rm marimo 2>/dev/null || true
        docker run -d \
            --name marimo \
            --restart unless-stopped \
            -p 8000:8000 \
            marimo-dashboards
        echo "$(date): Done. New version is live."
    fi
done
