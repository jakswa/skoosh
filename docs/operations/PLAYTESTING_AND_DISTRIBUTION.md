# Playtesting, hosting, and binary distribution

SKOOSH currently uses direct ENet connections over **UDP 9077**. Pointing a client at another host is already supported through either the lobby fields or command-line arguments.

## 1. Source checkout: one local server and two clients

From the repository root:

```bash
./tools/run_multiplayer_demo.sh
```

This starts a headless authoritative server and two graphical clients using `godot` from `PATH`. On a fresh or updated source checkout, it first refreshes Godot's ignored class and asset cache. Set `GODOT_BIN` to another command name or an absolute path, or override the UDP port, when needed:

```bash
GODOT_BIN=godot4 SKOOSH_PORT=9078 ./tools/run_multiplayer_demo.sh
```

Faultline Basin is the default rotation start. Set `SKOOSH_MAP_ID=cairn_steps`
to start on the other production map. Direct launches pass the corresponding
`--map=faultline_basin` or `--map=cairn_steps` assertion to the server and every
client. Map/hash agreement and a rollback baseline are checked before a local
playable avatar is admitted. Score-limit matches alternate production maps
without reconnecting clients.

Logs are written under the ignored `.tmp/skoosh-network` directory. Ctrl-C in the launching terminal stops the whole group. The two clients are assigned to opposing teams, so TEAM voice commands are intentionally private; press G in the open V menu to send a GLOBAL command that both clients can hear.

To run the processes separately:

```bash
# Once per fresh checkout, or open the project in the Godot editor
./tools/prepare_source_checkout.sh

# Terminal 1
/path/to/Godot --headless --path . -- --server --port=9077 --map=faultline_basin

# Terminals 2 and 3
/path/to/Godot --path . -- --join=127.0.0.1 --port=9077 --map=faultline_basin
```

Launching a client without arguments opens the lobby. Enter an address and port and press **JOIN SERVER**. **START SERVER** creates an authority-only server in that process; it does not create a local player, so two additional client processes are still required.

## 2. Local client connecting to a remote server

To open two local clients against one remote server:

```bash
./tools/run_remote_clients.sh play.example.com
```

Override the port with `SKOOSH_PORT=9078` and select Cairn with
`SKOOSH_MAP_ID=cairn_steps`. To launch only one client from source:

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

Install matching Godot 4.4 export templates, then run with the default `godot` command:

```bash
./tools/export_binaries.sh
```

As with the other source helpers, `GODOT_BIN` may name another command on `PATH` or an absolute executable path.

The script exports and packages:

```text
build/dist/skoosh-linux-client.tar.gz
build/dist/skoosh-windows-client.zip
build/dist/skoosh-macos-client.zip
build/dist/skoosh-linux-server.tar.gz
build/dist/SHA256SUMS
```

The PCK is embedded, so each current package contains one executable. Send a tester the client archive for their OS and the relevant server address. Publishing these files as GitHub Release assets is preferable to committing binaries to Git.

The equivalent manual export commands are:

```bash
godot --headless --path . --export-release "Linux Client"
godot --headless --path . --export-release "Windows Client"
godot --headless --path . --export-release "macOS Client"
godot --headless --path . --export-release "Linux Dedicated Server"
```

This repository has Linux, Windows, and universal macOS client presets plus a Linux server preset. The macOS archive is ad-hoc signed but not notarized, so Gatekeeper may require right-clicking the app and selecting **Open**. Windows may likewise warn about an unknown unsigned publisher. A Windows dedicated-server preset is not needed for the planned Linux hosting path.

Every push to `main` triggers `.github/workflows/integration.yml`. Linux, Windows, and macOS runners each export their native client, start a native headless server, and run two exported clients through the ground-jet and authoritative CTF acceptance scenarios. Source-only rotation, bootstrap, and transition fault-injection checks are listed in `docs/engineering/MAP_ROTATION_HANDOFF.md`. Other branches and pull requests do not trigger this matrix.

Tags matching `v*` trigger `.github/workflows/release.yml`. It first requires a successful three-OS `main` integration run for the exact tagged commit, then exports all four targets with pinned Godot 4.4.1 templates, writes checksums, and publishes a GitHub Release. Create a playtest release with:

```bash
git tag v0.1.0-playtest.1
git push origin main
git push origin v0.1.0-playtest.1
```

## 5. Fly.io experiment

A minimal container definition and illustrative Fly configuration live at:

```text
deploy/Dockerfile.server
deploy/fly.example.toml
```

First export the Linux dedicated server so `build/server/skoosh-server.x86_64` exists. Then choose a globally unique app name and nearby region:

```bash
APP=replace-with-your-skoosh-server-name
cp deploy/fly.example.toml fly.toml
sed -i "s/replace-with-your-skoosh-server-name/$APP/" fly.toml
fly apps create "$APP"
```

For the simplest ENet/UDP path, allocate a dedicated public IPv4 unless current Fly documentation explicitly supports the required UDP port on shared IPv4:

```bash
fly ips allocate-v4 --app "$APP"
```

A dedicated IPv4 may add a small monthly charge. Verify the current price before confirming, then deploy exactly one Machine:

```bash
fly deploy --app "$APP" --config fly.toml --remote-only --ha=false \
  --vm-size shared-cpu-1x --vm-memory 512
```

UDP 9077 is exposed by `fly.toml`. Auto-stop is disabled because a stopped Machine cannot reliably wake from raw game traffic. Platform networking requirements can change; verify Fly's current UDP guidance if deployment behavior differs.

After deployment, confirm the Machine, UDP service, public address, and server log before debugging the client:

```bash
fly status
fly services list
fly ips list
fly logs
```

Then connect two local clients:

```bash
./tools/run_remote_clients.sh replace-with-your-skoosh-server-name.fly.dev
```

Keep the first remote test to one region, one Machine, direct IP/hostname, and trusted testers. Do not add load balancing: ENet sessions require all packets for a player to reach the same authoritative process.

## 6. Version matching and troubleshooting

- Server and clients should come from the same Git commit/export batch. No protocol version handshake exists yet.
- Verify the server log contains `NETWORK server listening` and each `NETWORK peer joined` line.
- Verify the selected host firewall/cloud firewall allows UDP, not merely TCP.
- Make sure the client uses the externally exposed port if it differs from the server's internal port.
- A timeout with no server join log usually indicates DNS, NAT, firewall, cloud UDP configuration, or an incorrect address.
- Do not expose the editor itself; distribute exported binaries.
- Remote fairness remains experimental because latency/loss correction metrics and impaired-network projectile qualification are not implemented yet.
