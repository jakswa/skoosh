# Playtesting, hosting, and binary distribution

SKOOSH currently uses direct ENet connections over **UDP 9077**. Pointing a client at another host is already supported through either the lobby fields or command-line arguments.

## 1. Source checkout: one local server and two clients

From the repository root:

```bash
./tools/run_multiplayer_demo.sh
```

This starts a headless authoritative server and two graphical clients. Override the engine or UDP port when needed:

```bash
GODOT_BIN=/path/to/Godot SKOOSH_PORT=9078 ./tools/run_multiplayer_demo.sh
```

Logs are written under `/tmp/skoosh-network`. Ctrl-C in the launching terminal stops the whole group.

To run the processes separately:

```bash
# Terminal 1
/path/to/Godot --headless --path . -- --server --port=9077

# Terminals 2 and 3
/path/to/Godot --path . -- --join=127.0.0.1 --port=9077
```

Launching a client without arguments opens the lobby. Enter an address and port and press **JOIN SERVER**. **START SERVER** creates an authority-only server in that process; it does not create a local player, so two additional client processes are still required.

## 2. Local client connecting to a remote server

From a source checkout:

```bash
/path/to/Godot --path . -- --join=play.example.com --port=9077
```

From an exported client:

```bash
./skoosh.x86_64 -- --join=play.example.com --port=9077
```

On Windows PowerShell:

```powershell
.\skoosh.exe -- --join=play.example.com --port=9077
```

The command-line address may be a DNS hostname, public IP, private LAN IP, or `127.0.0.1`. The same values can be entered in the graphical lobby. The `--` separator is important: arguments after it are passed to SKOOSH rather than consumed by Godot.

## 3. Home-network server

Run the server on a wired Linux machine when possible:

```bash
./skoosh-server.x86_64 --headless -- --server --port=9077
```

Then:

1. Give the server machine a stable/reserved LAN address.
2. Allow inbound **UDP 9077** in its host firewall.
3. Forward **UDP 9077** on the router to that LAN address. TCP forwarding is not required.
4. Give remote testers the router's public hostname/IP and port.
5. Test from outside the LAN, such as a phone hotspot. Some routers do not support NAT loopback, so connecting to your own public address from inside can fail even when external access works.

If the router's WAN address differs from the address reported by an external IP-check service, the connection may be behind carrier-grade NAT. In that case ordinary port forwarding may not work; use a UDP-capable host instead.

There is currently no authentication, encryption, moderation, ban list, or denial-of-service protection. Treat this as a trusted, small playtest server and do not run unrelated sensitive services in the same container or account.

## 4. Exporting client and server binaries

Install matching Godot 4.4 export templates, then run:

```bash
GODOT_BIN=/path/to/Godot ./tools/export_binaries.sh
```

The script exports and packages:

```text
build/dist/skoosh-linux-client.tar.gz
build/dist/skoosh-windows-client.zip
build/dist/skoosh-linux-server.tar.gz
build/dist/SHA256SUMS
```

The PCK is embedded, so each current package contains one executable. Send a tester the client archive for their OS and the relevant server address. Publishing these files as GitHub Release assets is preferable to committing binaries to Git.

The equivalent manual export commands are:

```bash
godot --headless --path . --export-release "Linux Client"
godot --headless --path . --export-release "Windows Client"
godot --headless --path . --export-release "Linux Dedicated Server"
```

This repository currently has Linux client/server and Windows client presets. A Windows dedicated-server preset is not needed for the planned Linux hosting path.

## 5. Fly.io experiment

A minimal container definition and illustrative Fly configuration live at:

```text
deploy/Dockerfile.server
deploy/fly.example.toml
```

First export the Linux dedicated server so `build/server/skoosh-server.x86_64` exists. Then copy the example config, choose an app name and region, and use current Fly CLI instructions:

```bash
cp deploy/fly.example.toml fly.toml
fly apps create replace-with-your-skoosh-server-name
fly deploy --config fly.toml
```

Expose UDP 9077 and keep at least one Machine running during a playtest; an auto-stopped UDP server cannot wake from Godot traffic in every hosting configuration. Confirm Fly.io's current UDP service and public-IP requirements before relying on the example, as platform networking details can change.

After deployment, connect with the Fly hostname and port from the lobby or command line. Check server logs before debugging the client:

```bash
fly logs
```

Keep the first remote test to one region, one Machine, direct IP/hostname, and trusted testers. Do not add load balancing: ENet sessions require all packets for a player to reach the same authoritative process.

## 6. Version matching and troubleshooting

- Server and clients should come from the same Git commit/export batch. No protocol version handshake exists yet.
- Verify the server log contains `NETWORK server listening` and each `NETWORK peer joined` line.
- Verify the selected host firewall/cloud firewall allows UDP, not merely TCP.
- Make sure the client uses the externally exposed port if it differs from the server's internal port.
- A timeout with no server join log usually indicates DNS, NAT, firewall, cloud UDP configuration, or an incorrect address.
- Do not expose the editor itself; distribute exported binaries.
- Remote fairness remains experimental because latency/loss correction metrics and historical rifle hitbox rewind are not implemented yet.
