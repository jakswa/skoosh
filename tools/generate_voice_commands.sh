#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SKOOSH_ENV_FILE:-$ROOT/.env}"
OUTPUT_DIR="${SKOOSH_VOICE_OUTPUT_DIR:-$ROOT/audio/voice}"
TMP_ROOT="$ROOT/.tmp"
MODEL_ID="sonic-3.5-2026-05-04"
VOICE_ID="6776173b-fd72-460d-89b3-d85812ee518d"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing Cartesia environment file: $ENV_FILE" >&2
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffmpeg and ffprobe are required to normalize generated voice assets." >&2
  exit 1
fi

set +x
set -a
source "$ENV_FILE"
set +a
: "${CARTESIA_API_KEY:?CARTESIA_API_KEY is missing from $ENV_FILE}"

names=(
  hello
  goodbye
  thanks
  shazbot
  defend_our_standard
  push_far_platform
  recover_our_standard
  cover_my_return
  yes
  no
  need_support
  all_clear
)
lines=(
  "Hello!"
  "Goodbye."
  "Thanks!"
  "Shazbot!"
  "Lock down our standard."
  "Push the far platform."
  "Our standard is moving. Recover it."
  "Cover my return."
  "Yes."
  "No."
  "I need support."
  "All clear."
)

mkdir -p "$OUTPUT_DIR" "$TMP_ROOT"
for index in "${!names[@]}"; do
  temporary_wav="$(mktemp --tmpdir="$TMP_ROOT" --suffix=.wav)"
  trap 'rm -f "$temporary_wav"' EXIT
  payload="$(printf '{"model_id":"%s","transcript":"%s","voice":{"mode":"id","id":"%s"},"language":"en","output_format":{"container":"wav","encoding":"pcm_s16le","sample_rate":44100},"generation_config":{"speed":1.08,"volume":1.0}}' "$MODEL_ID" "${lines[$index]}" "$VOICE_ID")"
  curl --fail-with-body --silent --show-error \
    --request POST 'https://api.cartesia.ai/tts/bytes' \
    -H "Authorization: Bearer ${CARTESIA_API_KEY}" \
    -H 'Cartesia-Version: 2026-03-01' \
    -H 'Content-Type: application/json' \
    --data "$payload" \
    --output "$temporary_wav"
  ffprobe -v error "$temporary_wav"
  ffmpeg -hide_banner -loglevel error -y -i "$temporary_wav" \
    -ac 1 -ar 44100 -c:a pcm_s16le -af 'loudnorm=I=-18:TP=-2:LRA=7' \
    "$OUTPUT_DIR/${names[$index]}.wav"
  rm -f "$temporary_wav"
  trap - EXIT
  echo "Generated ${names[$index]}.wav"
done
