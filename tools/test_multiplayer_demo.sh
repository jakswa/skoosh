#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
CLIENT_BIN="${SKOOSH_CLIENT_BIN:-$GODOT_BIN}"
PORT="${SKOOSH_TEST_PORT:-19077}"
MAP_ID="${SKOOSH_TEST_MAP:-faultline_basin}"
TEST_SECONDS="${SKOOSH_TEST_SECONDS:-110}"
CLIENT_TEST_SECONDS=$((TEST_SECONDS + 1))
LOG_DIR="${SKOOSH_TEST_LOG_DIR:-$ROOT/.tmp/skoosh-network-test}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN to a command name or absolute path." >&2
  exit 1
fi
if ! command -v "$CLIENT_BIN" >/dev/null 2>&1; then
  echo "The client executable was not found on PATH. Set SKOOSH_CLIENT_BIN to a command name or absolute path." >&2
  exit 1
fi

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

pids=()
cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

"$GODOT_BIN" --headless --path "$ROOT" -- --server --port="$PORT" \
	--map="$MAP_ID" \
	--acceptance-mode \
  --test-seconds="$TEST_SECONDS" --require-combat --require-movement --require-ctf \
  --require-map-baseline \
  --require-voice --require-character-variants >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1

client_command=("$CLIENT_BIN" --headless)
if [[ "$CLIENT_BIN" == "$GODOT_BIN" ]]; then
  client_command+=(--path "$ROOT")
fi

for client in 1 2; do
  "${client_command[@]}" -- --join=127.0.0.1 --port="$PORT" \
		--map="$MAP_ID" \
		--acceptance-mode --bot --test-seconds="$CLIENT_TEST_SECONDS" --require-character-variants \
    >"$LOG_DIR/client-$client.log" 2>&1 &
  pids+=("$!")
done

set +e
wait "$server_pid"
status=$?
set -e

for pid in "${pids[@]:1}"; do
  set +e
  wait "$pid" 2>/dev/null
  client_status=$?
  set -e
  if [[ $client_status -ne 0 ]]; then
    status=$client_status
  fi
done

cat "$LOG_DIR/server.log"
if grep -Eq "ERROR:|SCRIPT ERROR|rejected" "$LOG_DIR"/*.log; then
  echo "Multiplayer acceptance logged an error or rejected launch. Logs: $LOG_DIR" >&2
  status=1
fi
if ! grep -q "MAP selected id=$MAP_ID .*status=production" "$LOG_DIR/server.log"; then
  echo "Server did not run the requested production map '$MAP_ID'. Logs: $LOG_DIR" >&2
  status=1
fi
for client in 1 2; do
  if ! grep -q "VOICE received.*scope=GLOBAL" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not receive a global voice command. Logs: $LOG_DIR" >&2
    status=1
  fi
  if ! grep -q "ACCEPT multiplayer.*score_limit=3" "$LOG_DIR/client-$client.log"; then
    echo "Client $client did not replicate the authoritative score limit. Logs: $LOG_DIR" >&2
    status=1
  fi
done
if ! perl -ne '$relayed = 1 if /VOICE received listener=(\d+) speaker=(\d+)/ && $1 != $2; END { exit($relayed ? 0 : 1) }' \
  "$LOG_DIR"/client-*.log; then
  echo "No client received a voice command from another peer. Logs: $LOG_DIR" >&2
  status=1
fi
if ! perl -ne '
  BEGIN { $accumulation_ok = 1 }
  if (/CTF capture .* score=(\d+)-(\d+) route=(\S+)/ && !$won) {
    $captures++;
    $accumulation_ok = 0 if $1 + $2 != $captures;
    $full_route = 1 if $captures == 1 && $3 eq "full";
    $accelerated_captures++ if $3 eq "acceptance_contacts";
  }
  if (/ACCEPT CTF acceleration enabled .*after_full_route_captures=1/) {
    $acceleration_after_route = 1 if $full_route && $captures == 1;
  }
  if (/ACCEPT CTF contact positioned .*contact=pickup/) { $accelerated_pickups++ }
  if (/ACCEPT CTF contact positioned .*contact=capture/) { $accelerated_contacts++ }
  if (/CTF objective ready score=/ && !$won) { $objective_resets++ }
  if (/CTF win .* score=(\d+)-(\d+)/ && !$won) {
    $won = 1;
    $limit_win = $1 + $2 == 3 && $captures == 3;
  }
  if (/CTF match started match=2 score=0-0/) { $match_reset = 1 }
  END {
    exit(
      $captures == 3 && $accumulation_ok != 0 && $full_route
      && $acceleration_after_route && $accelerated_captures == 2
      && $accelerated_pickups == 2 && $accelerated_contacts == 2
      && $objective_resets == 2 && $limit_win && $match_reset ? 0 : 1
    )
  }
' "$LOG_DIR/server.log"; then
  echo "Full-route capture followed by authoritative accelerated-contact score/limit/reset evidence was not observed. Logs: $LOG_DIR" >&2
  status=1
fi
if [[ $status -ne 0 ]]; then
  echo "Multiplayer acceptance failed. Client logs: $LOG_DIR" >&2
  exit "$status"
fi

echo "Multiplayer acceptance passed on $MAP_ID. Logs: $LOG_DIR"
