# Hosting marimo dashboards on your home server

> The goal is simplicity. 

This guide walks you through running [marimo](https://marimo.io) notebooks on a home server, accessible from any of your devices via [Tailscale](https://tailscale.com). Every `git push` can auto-deploy within a minute.

## Prerequisites

- A Linux machine with SSH access (e.g. a Raspberry Pi, old laptop, or mini PC)
- Docker installed ([docs](https://docs.docker.com/engine/install/))
- A free [Tailscale](https://tailscale.com) account

## Step 1 — Install Tailscale on your server

SSH into your server and run:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Follow the link to authorize the device. Then note your Tailscale IP:

```bash
tailscale ip -4
```

You can also find the IP or hostname in the [Tailscale admin console](https://login.tailscale.com/admin/machines).

## Step 2 — Clone and run

```bash
git clone <your-repo-url>
cd marimo-homelab
docker build -t marimo-dashboards .
docker run -d --name marimo --restart unless-stopped -p 8000:8000 marimo-dashboards
```

The `--restart unless-stopped` flag ensures the container comes back after a reboot.

## Step 3 — Access from anywhere

1. Install Tailscale on your phone, laptop, or any device you want to use.
2. Open your browser and go to:

```
http://<tailscale-ip>:8000
```

You should see the stocks demo notebook.

## Step 4 — Enable HTTPS via Tailscale Serve (optional)

Raw `http://<tailscale-ip>:8000` works, but a MagicDNS hostname with a real TLS certificate is nicer — especially on mobile browsers, where some WebSocket features behave better over HTTPS. Tailscale Serve handles both in one command.

Prerequisite: enable HTTPS for your tailnet in the [admin console → DNS → HTTPS Certificates](https://login.tailscale.com/admin/dns).

On the server:

```bash
sudo tailscale serve --bg http://localhost:8000
```

The dashboard is now reachable at:

```
https://<your-server-hostname>.<your-tailnet>.ts.net
```

- `--bg` persists the config, so it comes back after a reboot.
- Inspect with `tailscale serve status`.
- Tear down with `sudo tailscale serve reset`.

The original `http://<tailscale-ip>:8000` URL keeps working — Serve is layered on top of the container's published port, not a replacement.

## Step 5 — Auto-deploy (optional)

The included `deploy.sh` script checks for new commits and rebuilds the container only when something has changed. Wire it up to cron to run every minute:

```bash
crontab -e
```

First, find the absolute path to `deploy.sh` — you'll need it in the cron line:

```bash
realpath ./deploy.sh
```

Copy that output. Then add this line to your crontab, **replacing `<PASTE-PATH-HERE>` with the path you just copied**:

```
* * * * * flock -n /tmp/marimo-deploy.lock <PASTE-PATH-HERE> >> $HOME/marimo-deploy.log 2>&1
```

> ⚠️ Common mistake: don't leave a placeholder like `/path/to/...` in the crontab. Cron will silently fail every minute and no log file will ever appear.

That's it. Every minute cron will run `deploy.sh`, which does a cheap `git fetch` and exits immediately if there are no new commits. When you `git push`, the next tick will pull, rebuild, and restart the container.

The `flock -n` prevents overlapping runs if a build takes longer than a minute. The log lives in your home directory so no `sudo` is needed to write it.

### Verify it's working

Wait a minute, then tail the log:

```bash
tail -f ~/marimo-deploy.log
```

You should see output within ~60 seconds — either "deploying..." messages or nothing (which is normal when there's nothing to do and the container is running).

If the file never appears, cron isn't running your line. Check these in order:

1. **Make sure your crontab line uses the real absolute path**, not a `~` or `$HOME` — cron doesn't always expand those in the *command* position. (It does expand them in `>>` redirection on most systems, but the safest bet is to hard-code the script path.)
2. **Check cron's own log** for errors: `grep CRON /var/log/syslog | tail` (Debian/Ubuntu) or `journalctl -u cron --since '5 min ago'`.
3. **Make sure your user can talk to Docker** without sudo: `docker info`. If it fails, run `sudo usermod -aG docker $USER`, then log out and back in. The updated `deploy.sh` will now print a clear error if this is the problem.

## Tips

- **No port forwarding needed.** Tailscale creates a private WireGuard mesh network between your devices. Your server is never exposed to the public internet.
- **HTTPS** is covered by Step 4 above (`tailscale serve`). For a bare certificate without the proxy, `tailscale cert` is the lower-level alternative.
- **Add more notebooks** by dropping `.py` files into the `notebooks/` directory. Each notebook declares its own dependencies via [PEP 723](https://peps.python.org/pep-0723/) inline metadata — no shared `requirements.txt` needed.
- **Check the deploy log live** via `tail -f ~/marimo-deploy.log` and make a change to the readme of your fork. If you wait a minute you should see the build appear. 
