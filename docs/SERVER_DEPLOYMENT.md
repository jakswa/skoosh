# SKOOSH dedicated-server deployment

This deploys one authoritative Linux server using ENet over **UDP 9077**. Server and clients must come from the same Git commit/release; there is no protocol-version handshake yet.

## Choose one installation path

### A. Prebuilt GitHub Release binary

Download `skoosh-linux-server.tar.gz` and `SHA256SUMS` from the same release, verify it, then install:

```bash
sha256sum --check SHA256SUMS --ignore-missing
tar -xzf skoosh-linux-server.tar.gz
sudo install -d -o root -g root /opt/skoosh
sudo install -m 0755 skoosh-server.x86_64 /opt/skoosh/skoosh-server
```

The release binary has its Godot PCK embedded; no other game files or Godot installation are required.

### B. Git checkout

Install the pinned Godot 4.4.1 Linux executable, then:

```bash
sudo git clone https://github.com/jakswa/skoosh.git /opt/skoosh
cd /opt/skoosh
sudo git checkout COMMIT_OR_RELEASE_TAG
sudo install -m 0755 /path/to/Godot_v4.4.1-stable_linux.x86_64 /opt/skoosh/godot
```

Running from source does not require Godot export templates.

## Service account

```bash
sudo useradd --system --home-dir /var/lib/skoosh --create-home --shell /usr/sbin/nologin skoosh
sudo chown -R root:root /opt/skoosh
```

## systemd service

Create `/etc/systemd/system/skoosh.service`:

```ini
[Unit]
Description=SKOOSH authoritative game server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=skoosh
Group=skoosh
WorkingDirectory=/var/lib/skoosh
Environment=HOME=/var/lib/skoosh
# Prebuilt release binary:
ExecStart=/opt/skoosh/skoosh-server --headless -- --server --port=9077
# For a Git checkout, replace ExecStart with:
# ExecStart=/opt/skoosh/godot --headless --path /opt/skoosh -- --server --port=9077
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/skoosh

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now skoosh
sudo systemctl status skoosh
sudo journalctl -u skoosh -f
```

A healthy startup includes:

```text
NETWORK server listening port=9077 max_clients=16
NETWORK authoritative CTF server started peer=1 capture_limit=1
```

## Network configuration

1. Give the server a stable/reserved LAN IP.
2. Allow inbound **UDP 9077** in the host firewall. TCP is not required.
3. Forward router WAN **UDP 9077** to server LAN **UDP 9077**.
4. Point the playtest hostname's DNS `A` record at the router's public IPv4.
5. Test from outside the LAN; NAT loopback may prevent testing the public hostname from inside.

Example UFW rule:

```bash
sudo ufw allow 9077/udp
```

Useful checks:

```bash
sudo ss -lunp | grep ':9077'
sudo journalctl -u skoosh -n 100 --no-pager
dig +short server.example.com A
```

A joining player produces `NETWORK peer joined` and `NETWORK avatar spawned` log lines. If no join reaches the log, check UDP forwarding, host/router firewalls, DNS, and whether the ISP uses carrier-grade NAT.

## Client connection

Players enter the hostname and `9077` in the lobby, or run:

```bash
skoosh.x86_64 -- --join=server.example.com --port=9077
```

Two clients from a source checkout can be launched with:

```bash
./tools/run_remote_clients.sh server.example.com
```

## Updating

Stop the service, replace the binary or check out the exact new commit/tag, then restart:

```bash
sudo systemctl stop skoosh
# Install new binary, or: cd /opt/skoosh && sudo git fetch && sudo git checkout COMMIT_OR_TAG
sudo systemctl start skoosh
sudo journalctl -u skoosh -n 50 --no-pager
```

Distribute clients from the same build. Roll back by restoring the prior binary or Git commit.

## Current operational limitations

This is a trusted-playtest server: no authentication, encryption, administration console, ban list, discovery, automatic updates, or DDoS protection. Historical rifle hitbox rewind and impaired-network qualification are also pending. Do not colocate sensitive workloads solely behind this process, and expose only the required UDP port.
