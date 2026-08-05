#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
JOBS="${SKOOSH_TEST_JOBS:-2}"
PORT_BASE="${SKOOSH_SUITE_PORT_BASE:-21000}"
SUITE_DIR="${SKOOSH_SUITE_LOG_DIR:-$ROOT/.tmp/skoosh-headless-suite-$(date +%Y%m%d-%H%M%S)-$$}"

long_tests=(
	multiplayer-faultline
	multiplayer-cairn
	network-bootstrap
	map-rotation
	rotation-ready-timeout
	rotation-prepare-disconnect
)
fast_tests=(
	asset-pipeline
	character-variants
	competitive-maps
	ground-jet
	map-mismatch
	oob-recovery
	projectile-presentation
	rotation-lifecycle
	score-limit-cli
)
all_tests=("${long_tests[@]}" "${fast_tests[@]}")


usage() {
	cat <<'EOF'
Usage: ./tools/run_headless_tests.sh [all|fast|long|TEST ...]

Runs the complete source test suite by default. Set SKOOSH_TEST_JOBS=1..4 to
control concurrency, and use --list to print individual scenario names.
EOF
}


list_tests() {
	printf '%s\n' "${all_tests[@]}"
}


contains_test() {
	local candidate="$1"
	local known
	for known in "${all_tests[@]}"; do
		if [[ "$candidate" == "$known" ]]; then
			return 0
		fi
	done
	return 1
}


requires_exclusive_worker() {
	case "$1" in
		network-bootstrap|map-rotation|rotation-ready-timeout|rotation-prepare-disconnect)
			return 0
			;;
		*)
			return 1
			;;
	esac
}


append_unique() {
	local candidate="$1"
	local selected
	for selected in "${selected_tests[@]:-}"; do
		if [[ "$candidate" == "$selected" ]]; then
			return
		fi
	done
	selected_tests+=("$candidate")
}


run_scenario() {
	local name="$1"
	local artifact_dir="$SUITE_DIR/artifacts/$name"
	local user_dir="$SUITE_DIR/user/$name"
	local -a isolated_env=(
		"GODOT_BIN=$GODOT_BIN"
		"HOME=$user_dir/home"
		"XDG_DATA_HOME=$user_dir/data"
		"XDG_CONFIG_HOME=$user_dir/config"
		"XDG_CACHE_HOME=$user_dir/cache"
	)
	mkdir -p "$artifact_dir" "${user_dir}/home" "${user_dir}/data" \
		"${user_dir}/config" "${user_dir}/cache"

	case "$name" in
		multiplayer-faultline)
			run_bounded 150s env "${isolated_env[@]}" \
				SKOOSH_CLIENT_BIN="$GODOT_BIN" \
				SKOOSH_TEST_PORT="$((PORT_BASE + 0))" \
				SKOOSH_TEST_MAP=faultline_basin \
				SKOOSH_TEST_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_multiplayer_demo.sh"
			;;
		multiplayer-cairn)
			run_bounded 150s env "${isolated_env[@]}" \
				SKOOSH_CLIENT_BIN="$GODOT_BIN" \
				SKOOSH_TEST_PORT="$((PORT_BASE + 1))" \
				SKOOSH_TEST_MAP=cairn_steps \
				SKOOSH_TEST_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_multiplayer_demo.sh"
			;;
		network-bootstrap)
			run_bounded 120s env "${isolated_env[@]}" \
				SKOOSH_BOOTSTRAP_TEST_PORT="$((PORT_BASE + 200))" \
				SKOOSH_BOOTSTRAP_LOG_DIR="$artifact_dir" \
				SKOOSH_BOOTSTRAP_QUICK=0 \
				"$ROOT/tools/test_network_bootstrap.sh"
			;;
		map-rotation)
			run_bounded 120s env "${isolated_env[@]}" \
				SKOOSH_ROTATION_TEST_PORT="$((PORT_BASE + 3))" \
				SKOOSH_ROTATION_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_map_rotation.sh"
			;;
		rotation-ready-timeout)
			run_bounded 90s env "${isolated_env[@]}" \
				SKOOSH_READY_TIMEOUT_TEST_PORT="$((PORT_BASE + 210))" \
				SKOOSH_READY_TIMEOUT_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_rotation_ready_timeout.sh"
			;;
		rotation-prepare-disconnect)
			run_bounded 90s env "${isolated_env[@]}" \
				SKOOSH_PREPARE_DISCONNECT_TEST_PORT="$((PORT_BASE + 211))" \
				SKOOSH_PREPARE_DISCONNECT_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_rotation_prepare_disconnect.sh"
			;;
		asset-pipeline)
			run_bounded 60s env "${isolated_env[@]}" "$ROOT/tools/test_asset_pipeline.sh"
			;;
		character-variants)
			run_bounded 60s env "${isolated_env[@]}" \
				SKOOSH_CHARACTER_TEST_PORT="$((PORT_BASE + 4))" \
				SKOOSH_CHARACTER_TEST_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_character_variants.sh"
			;;
		competitive-maps)
			run_bounded 60s env "${isolated_env[@]}" "$ROOT/tools/test_competitive_maps.sh"
			;;
		ground-jet)
			run_bounded 60s env "${isolated_env[@]}" "$ROOT/tools/test_ground_jet.sh"
			;;
		map-mismatch)
			run_bounded 60s env "${isolated_env[@]}" \
				SKOOSH_TEST_PORT="$((PORT_BASE + 2))" \
				SKOOSH_TEST_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_map_mismatch.sh"
			;;
		oob-recovery)
			run_bounded 60s env "${isolated_env[@]}" \
				SKOOSH_OOB_TEST_PORT="$((PORT_BASE + 5))" \
				SKOOSH_OOB_TEST_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_oob_recovery.sh"
			;;
		projectile-presentation)
			run_bounded 60s env "${isolated_env[@]}" "$ROOT/tools/test_projectile_presentation.sh"
			;;
		rotation-lifecycle)
			run_bounded 60s env "${isolated_env[@]}" \
				SKOOSH_ROTATION_LIFECYCLE_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_rotation_lifecycle.sh"
			;;
		score-limit-cli)
			run_bounded 60s env "${isolated_env[@]}" \
				SKOOSH_SCORE_LIMIT_TEST_PORT="$((PORT_BASE + 100))" \
				SKOOSH_SCORE_LIMIT_LOG_DIR="$artifact_dir" \
				"$ROOT/tools/test_score_limit_cli.sh"
			;;
	esac
}


run_bounded() {
	local duration="$1"
	shift
	local command_pid
	local status

	timeout --foreground --kill-after=5s "$duration" "$@" &
	command_pid=$!
	trap 'kill "$command_pid" 2>/dev/null || true' TERM INT
	set +e
	wait "$command_pid"
	status=$?
	set -e
	trap - TERM INT
	return "$status"
}


if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot 4.4+ was not found on PATH. Install godot or set GODOT_BIN." >&2
	exit 1
fi
if ! command -v timeout >/dev/null 2>&1; then
	echo "GNU timeout is required to run the parallel headless suite." >&2
	exit 1
fi
if [[ ! "$JOBS" =~ ^[1-4]$ ]]; then
	echo "SKOOSH_TEST_JOBS must be an integer from 1 through 4; received '$JOBS'." >&2
	exit 1
fi
if [[ ! "$PORT_BASE" =~ ^[0-9]+$ ]] || ((PORT_BASE < 1024 || PORT_BASE > 65324)); then
	echo "SKOOSH_SUITE_PORT_BASE must be an integer from 1024 through 65324." >&2
	exit 1
fi

selected_tests=()
if (($# == 0)); then
	selected_tests=("${all_tests[@]}")
else
	for argument in "$@"; do
		case "$argument" in
			all) for test_name in "${all_tests[@]}"; do append_unique "$test_name"; done ;;
			fast) for test_name in "${fast_tests[@]}"; do append_unique "$test_name"; done ;;
			long) for test_name in "${long_tests[@]}"; do append_unique "$test_name"; done ;;
			--list) list_tests; exit ;;
			-h|--help) usage; exit ;;
			*)
				if ! contains_test "$argument"; then
					echo "Unknown test or group: $argument" >&2
					usage >&2
					exit 2
				fi
				append_unique "$argument"
				;;
		esac
	done
fi

mkdir -p "$SUITE_DIR/output" "$SUITE_DIR/artifacts" "$SUITE_DIR/user"
GODOT_BIN="$(command -v "$GODOT_BIN")"
export GODOT_BIN

echo "Preparing project before parallel test execution..."
if ! SKOOSH_IMPORT_LOG="$SUITE_DIR/output/import.log" \
	"$ROOT/tools/prepare_source_checkout.sh" >"$SUITE_DIR/output/prepare.log" 2>&1; then
	cat "$SUITE_DIR/output/prepare.log" >&2
	if [[ -f "$SUITE_DIR/output/import.log" ]]; then
		cat "$SUITE_DIR/output/import.log" >&2
	fi
	echo "Godot preparation failed. Logs: $SUITE_DIR" >&2
	exit 1
fi
echo "Running ${#selected_tests[@]} scenarios with $JOBS workers. Logs: $SUITE_DIR"

declare -A test_by_pid=()
declare -A started_by_pid=()
failures=()
active=0


cleanup() {
	local pid
	for pid in "${!test_by_pid[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
	for pid in "${!test_by_pid[@]}"; do
		wait "$pid" 2>/dev/null || true
	done
}
trap cleanup EXIT
trap 'trap - EXIT; cleanup; exit 130' INT TERM


reap_one() {
	local finished_pid=""
	local status
	set +e
	wait -n -p finished_pid
	status=$?
	set -e
	local name="${test_by_pid[$finished_pid]}"
	local elapsed=$((SECONDS - started_by_pid[$finished_pid]))
	unset 'test_by_pid[$finished_pid]' 'started_by_pid[$finished_pid]'
	active=$((active - 1))
	if ((status == 0)); then
		echo "PASS  $name (${elapsed}s)"
	else
		echo "FAIL  $name (${elapsed}s, exit $status)" >&2
		cat "$SUITE_DIR/output/$name.log" >&2
		failures+=("$name")
	fi
}


for test_name in "${selected_tests[@]}"; do
	if requires_exclusive_worker "$test_name"; then
		# World-transition fixtures enforce real-time protocol deadlines and become
		# false negatives when another multi-process transition builds terrain.
		while ((active > 0)); do
			reap_one
		done
	fi
	while ((active >= JOBS)); do
		reap_one
	done
	echo "START $test_name"
	started_at=$SECONDS
	run_scenario "$test_name" >"$SUITE_DIR/output/$test_name.log" 2>&1 &
	pid=$!
	test_by_pid[$pid]="$test_name"
	started_by_pid[$pid]="$started_at"
	active=$((active + 1))
	if requires_exclusive_worker "$test_name"; then
		reap_one
	fi
done
while ((active > 0)); do
	reap_one
done
trap - EXIT INT TERM

if ((${#failures[@]} > 0)); then
	echo "Headless suite failed: ${failures[*]}. Logs: $SUITE_DIR" >&2
	exit 1
fi

echo "Headless suite passed (${#selected_tests[@]} scenarios). Logs: $SUITE_DIR"
