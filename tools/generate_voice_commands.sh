#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SKOOSH_ENV_FILE:-$ROOT/.env}"
OUTPUT_DIR="${SKOOSH_VOICE_OUTPUT_DIR:-$ROOT/audio/voice}"
REQUESTED_PACKS="${SKOOSH_VOICE_PACKS:-}"
REQUESTED_CLIPS="${SKOOSH_VOICE_CLIPS:-}"
TMP_ROOT="$ROOT/.tmp"
MODEL_ID="sonic-3.5-2026-05-04"
RADIO_FILTER='highpass=f=280:p=2,lowpass=f=3600:p=2,equalizer=f=1700:t=q:w=1.1:g=3.5,acompressor=threshold=0.1:ratio=4:attack=4:release=70:makeup=2,acrusher=bits=11:samples=1.35:mix=0.14:mode=lin,loudnorm=I=-16:TP=-1.5:LRA=5'

voice_names=(
  zack
  renee
  clint
  brittany
  jasper
)
voice_ids=(
  ed81fd13-2016-4a49-8fe3-c0d2761695fc
  c2ac25f9-ecc4-4f56-9095-651354df60c0
  db69127a-dbaf-4fa9-b425-2fe67680c348
  46788d8e-cdf9-4d5c-9125-094eb2e4d44c
  e98bd614-9b9d-4031-b930-ed72482af858
)
clip_names=(
  hello
  goodbye
  thanks
  shazbot
  defend_our_flag
  push_far_platform
  recover_our_flag
  cover_my_return
  yes
  no
  need_support
  all_clear
)
transcripts=(
  "Hello!"
  "Goodbye!"
  "Thanks!"
  "Shazbot!"
  "Defend our flag!"
  "Push the far platform!"
  "Recover our flag!"
  "Cover my return!"
  "Yes!"
  "No!"
  "I need support!"
  "All clear!"
)

if [[ -f "$ENV_FILE" ]]; then
  set +x
  set -a
  source "$ENV_FILE"
  set +a
fi
: "${CARTESIA_API_KEY:?CARTESIA_API_KEY is missing; set it or add it to $ENV_FILE}"

if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo "ffmpeg and ffprobe are required to process generated voice assets." >&2
  exit 1
fi

pack_requested() {
  local pack="$1"
  [[ -z "$REQUESTED_PACKS" || ",${REQUESTED_PACKS}," == *",${pack},"* ]]
}

clip_requested() {
  local clip="$1"
  [[ -z "$REQUESTED_CLIPS" || ",${REQUESTED_CLIPS}," == *",${clip},"* ]]
}

mkdir -p "$OUTPUT_DIR" "$TMP_ROOT"
for voice_index in "${!voice_names[@]}"; do
  voice_name="${voice_names[$voice_index]}"
  voice_id="${voice_ids[$voice_index]}"
  if ! pack_requested "$voice_name"; then
    continue
  fi
  pack_dir="$OUTPUT_DIR/$voice_name"
  mkdir -p "$pack_dir"

  for clip_index in "${!clip_names[@]}"; do
    clip_name="${clip_names[$clip_index]}"
    transcript="${transcripts[$clip_index]}"
    if ! clip_requested "$clip_name"; then
      continue
    fi
    temporary_wav="$(mktemp --tmpdir="$TMP_ROOT" --suffix=.wav)"
    trap 'rm -f "$temporary_wav"' EXIT
    payload="$(VOICE_ID="$voice_id" TRANSCRIPT="$transcript" MODEL_ID="$MODEL_ID" python3 - <<'PY'
import json
import os

print(json.dumps({
    "model_id": os.environ["MODEL_ID"],
    "transcript": os.environ["TRANSCRIPT"],
    "voice": {"mode": "id", "id": os.environ["VOICE_ID"]},
    "language": "en",
    "output_format": {
        "container": "wav",
        "encoding": "pcm_s16le",
        "sample_rate": 44100,
    },
    "generation_config": {"speed": 1.12, "volume": 1.0},
}))
PY
)"
    curl --fail-with-body --silent --show-error \
      --request POST 'https://api.cartesia.ai/tts/bytes' \
      -H "Authorization: Bearer ${CARTESIA_API_KEY}" \
      -H 'Cartesia-Version: 2026-03-01' \
      -H 'Content-Type: application/json' \
      --data "$payload" \
      --output "$temporary_wav"
    ffprobe -v error "$temporary_wav"
    ffmpeg -hide_banner -loglevel error -y -i "$temporary_wav" \
      -ac 1 -ar 11025 -c:a pcm_u8 -af "$RADIO_FILTER" \
      "$pack_dir/${clip_name}.wav"
    rm -f "$temporary_wav"
    trap - EXIT
    echo "Generated $voice_name/${clip_name}.wav"
  done
done

(
  cd "$OUTPUT_DIR"
  find . -mindepth 2 -maxdepth 2 -name '*.wav' -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
)
echo "Updated $OUTPUT_DIR/SHA256SUMS"
