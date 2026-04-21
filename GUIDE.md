# Hosting marimo dashboards on your home server

This guide walks you through running [marimo](https://marimo.io) notebooks on a home server, accessible from any of your devices via [Tailscale](https://tailscale.com). Every `git push` can auto-deploy within 30 seconds.

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

## Step 4 — Auto-deploy (optional)

The included `watch-docker.sh` script polls git every 30 seconds and rebuilds the container when new commits arrive. To run it as a system service:

1. Create a systemd unit file:

```bash
sudo tee /etc/systemd/system/marimo-watcher.service > /dev/null <<EOF
[Unit]
Description=Watch for marimo dashboard updates
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/path/to/marimo-homelab
ExecStart=/path/to/marimo-homelab/watch-docker.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

2. Update the paths in the file above, then enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable marimo-watcher
sudo systemctl start marimo-watcher
```

Now every `git push` to your repo will auto-deploy within 30 seconds.

## Tips

- **No port forwarding needed.** Tailscale creates a private WireGuard mesh network between your devices. Your server is never exposed to the public internet.
- **HTTPS is available** via `tailscale cert` if you want encrypted connections within your tailnet.
- **Add more notebooks** by dropping `.py` files into the `notebooks/` directory. Each notebook declares its own dependencies via [PEP 723](https://peps.python.org/pep-0723/) inline metadata — no shared `requirements.txt` needed.
- **Check the watcher logs** with `journalctl -u marimo-watcher -f` if something goes wrong during auto-deploy.
