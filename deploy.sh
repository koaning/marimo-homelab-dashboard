#!/bin/bash
# One-shot deploy: if the remote has new commits or the container is missing,
# pull and restart the container.
# Intended to be run from cron every minute.

# Safety flags:
#   -e  exit immediately if any command fails
#   -u  treat unset variables as an error
#   -o pipefail  fail a pipeline if any step in it fails (not just the last)
set -euo pipefail

# Run from the script's own directory so git/docker see the right repo,
# regardless of where cron invokes us from.
cd "$(dirname "$0")"

# Download remote commits into our local git cache. This does NOT modify
# working files — it just lets us compare local vs remote below.
git fetch origin

# Grab the commit hashes of our local HEAD and the upstream branch.
# `@{u}` is shorthand for "the upstream branch this one is tracking".
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

# Bail early with a helpful message if this user can't talk to Docker.
# Usually means the user isn't in the `docker` group.
# `>/dev/null 2>&1` throws away both stdout and stderr so we only show our own message.
if ! docker info >/dev/null 2>&1; then
  echo "$(date): cannot access Docker. Run with sudo or add this user to the docker group." >&2
  exit 1
fi

# Look up the container by exact name `marimo` (the `^/marimo$` regex pins it).
# `-a` includes stopped containers; `-q` returns only the ID (empty if none).
CONTAINER_ID=$(docker ps -aq --filter name='^/marimo$')

# Happy path: no new commits AND a container exists. Check if it's actually running.
# If it is, there's nothing to do — exit quietly (cron log stays clean).
if [ "$LOCAL" = "$REMOTE" ] && [ -n "$CONTAINER_ID" ]; then
  RUNNING=$(docker inspect -f '{{.State.Running}}' marimo 2>/dev/null || echo false)
  [ "$RUNNING" = "true" ] && exit 0
fi

# We're redeploying. Either new code arrived, or the container vanished/stopped.
echo "$(date): new commits ($LOCAL -> $REMOTE), deploying..."

# Only pull when there are actually new commits. `--ff-only` refuses anything
# that would require a merge, keeping the server's history clean.
if [ "$LOCAL" != "$REMOTE" ]; then
  git pull --ff-only
else
  echo "$(date): no new commits, but marimo is missing or stopped; redeploying..."
fi

# Rebuild the image from the current working tree.
docker build -t marimo-dashboards .

# Stop and remove any existing container. `|| true` means "don't fail the script
# if there's nothing to stop/remove" — e.g. first deploy, or the container already died.
docker stop marimo 2>/dev/null || true
docker rm marimo 2>/dev/null || true

# Start a fresh container:
#   -d                      run in background (detached)
#   --name marimo           give it a stable name so the checks above can find it
#   --restart unless-stopped   auto-restart after reboots or crashes, unless we stopped it
#   -p 8000:8000            expose container port 8000 on the host's port 8000
docker run -d --name marimo --restart unless-stopped -p 8000:8000 marimo-dashboards

echo "$(date): deploy complete."
