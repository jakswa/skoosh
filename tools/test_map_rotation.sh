#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${SKOOSH_ROTATION_TEST_PORT:-19079}"
TEST_SECONDS="${SKOOSH_ROTATION_TEST_SECONDS:-70}"
CLIENT_TEST_SECONDS=$((TEST_SECONDS - 5))
LOG_DIR="${SKOOSH_ROTATION_LOG_DIR:-$ROOT/.tmp/skoosh-map-rotation-test}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN." >&2
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
  --map=faultline_basin --score-limit=3 --acceptance-mode --require-rotation \
  --require-movement --require-ctf --require-character-variants \
  --test-seconds="$TEST_SECONDS" >"$LOG_DIR/server.log" 2>&1 &
server_pid=$!
pids+=("$server_pid")
sleep 1

for client in 1 2; do
  "$GODOT_BIN" --headless --path "$ROOT" -- --join=127.0.0.1 --port="$PORT" \
    --map=faultline_basin --acceptance-mode --bot --require-rotation \
    --require-character-variants --test-seconds="$CLIENT_TEST_SECONDS" \
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
if grep -Eq "ERROR:|SCRIPT ERROR|WARNING:|rejected|contract=FAIL|result=FAIL" "$LOG_DIR"/*.log; then
  echo "Map rotation acceptance logged an error or failed contract. Logs: $LOG_DIR" >&2
  status=1
fi
for log in "$LOG_DIR/server.log" "$LOG_DIR/client-1.log" "$LOG_DIR/client-2.log"; do
  if ! grep -q "ACCEPT rotation .*result=PASS.*generation=3 map=faultline_basin.*avatars=2" "$log"; then
    echo "Rotation result missing from $log. Logs: $LOG_DIR" >&2
    status=1
  fi
  if ! grep -q "WORLD active peer=.* generation=3 map=faultline_basin.*avatars=2" "$log"; then
    echo "Final Faultline generation was not active with two avatars in $log. Logs: $LOG_DIR" >&2
    status=1
  fi
  if ! perl -ne '
    if (/WORLD built generation=(\d+) map=(\S+) hash=(\S+) signature=(\S+).*contract=PASS/) {
      $seen{$1} = "$2/$3/$4";
    }
    END {
      exit(keys(%seen) == 3 && $seen{1} =~ /^faultline_basin\// &&
        $seen{2} =~ /^cairn_steps\// && $seen{3} =~ /^faultline_basin\// &&
        $seen{1} eq $seen{3} ? 0 : 1);
    }
  ' "$log"; then
    echo "Real terrain/world signatures did not prove Faultline -> Cairn -> Faultline in $log." >&2
    status=1
	fi
done
perl -ne 'print "$1/$2/$3/$4\n" if /WORLD built generation=(\d+) map=(\S+) hash=(\S+) signature=(\S+).*contract=PASS/' \
	"$LOG_DIR/server.log" >"$LOG_DIR/server-worlds.txt"
for client in 1 2; do
	perl -ne 'print "$1/$2/$3/$4\n" if /WORLD built generation=(\d+) map=(\S+) hash=(\S+) signature=(\S+).*contract=PASS/' \
		"$LOG_DIR/client-$client.log" >"$LOG_DIR/client-$client-worlds.txt"
	if ! cmp -s "$LOG_DIR/server-worlds.txt" "$LOG_DIR/client-$client-worlds.txt"; then
		echo "Client $client world generation/hash/terrain signatures differ from the server. Logs: $LOG_DIR" >&2
		status=1
	fi
done
if ! grep -q "ACCEPT rotation role=server.*movement={ 1: true, 2: true, 3: true }.*combat={ 1: true, 2: true, 3: true }.*captures={ 1: 3, 2: 3, 3: 1 }" "$LOG_DIR/server.log"; then
  echo "Movement, combat, and capture did not continue through both rotations. Logs: $LOG_DIR" >&2
  status=1
fi
if [[ $status -ne 0 ]]; then
  echo "Map rotation acceptance failed. Logs: $LOG_DIR" >&2
  exit "$status"
fi

echo "Map rotation acceptance passed: Faultline -> Cairn -> Faultline with two preserved peers. Logs: $LOG_DIR"
