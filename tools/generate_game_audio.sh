#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIO_ROOT="$ROOT/audio/generated"
RATE=48000

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to generate game audio." >&2
  exit 1
fi

mkdir -p \
  "$AUDIO_ROOT/ambience" \
  "$AUDIO_ROOT/movement" \
  "$AUDIO_ROOT/music" \
  "$AUDIO_ROOT/objective" \
  "$AUDIO_ROOT/preview" \
  "$AUDIO_ROOT/ui" \
  "$AUDIO_ROOT/weapons"

render_wav() {
  local output="$1"
  local duration="$2"
  local expression="$3"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "aevalsrc=exprs='$expression':s=$RATE:d=$duration" \
    -af "alimiter=limit=0.92:level=false" \
    -ar "$RATE" -ac 1 -c:a pcm_s16le "$output"
}

render_loop() {
  local output="$1"
  local duration="$2"
  local expression="$3"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "aevalsrc=exprs='$expression':s=$RATE:d=$duration" \
    -af "alimiter=limit=0.88:level=false" \
    -ar "$RATE" -ac 1 -c:a libvorbis -q:a 5 "$output"
}

# Movement layers are intentionally restrained so speed, ski contact, and jet
# state can be mixed continuously by the client rather than baked together.
render_loop "$AUDIO_ROOT/movement/wind_loop.ogg" 12 \
  "0.055*(sin(2*PI*137*t)+0.7*sin(2*PI*211*t)+0.45*sin(2*PI*353*t))*(0.78+0.22*sin(2*PI*t/12))"
render_loop "$AUDIO_ROOT/movement/ski_loop.ogg" 8 \
  "0.045*(sin(2*PI*487*t)+0.65*sin(2*PI*733*t)+0.4*sin(2*PI*1097*t))*(0.75+0.25*sin(2*PI*t/8))"
render_loop "$AUDIO_ROOT/movement/jet_loop.ogg" 6 \
  "0.12*sin(2*PI*73*t)+0.045*sin(2*PI*146*t)+0.028*sin(2*PI*947*t)*(0.7+0.3*sin(2*PI*t/6))"
render_wav "$AUDIO_ROOT/movement/land.wav" 0.42 \
  "(1-exp(-90*t))*exp(-9*t)*(0.34*sin(2*PI*(72-32*t)*t)+0.10*sin(2*PI*431*t))*(1-t/0.42)"
render_wav "$AUDIO_ROOT/movement/jet_empty.wav" 0.38 \
  "(1-exp(-70*t))*exp(-7*t)*(0.18*sin(2*PI*(420-760*t)*t)+0.08*sin(2*PI*93*t))*(1-t/0.38)"

# Four distinct launch signatures and two impact families.
render_wav "$AUDIO_ROOT/weapons/disc_fire.wav" 0.62 \
  "(1-exp(-110*t))*exp(-5.5*t)*(0.24*sin(2*PI*(128+760*t)*t)+0.12*sin(2*PI*(62+180*t)*t)+0.045*sin(2*PI*1247*t))*(1-t/0.62)"
render_wav "$AUDIO_ROOT/weapons/grenade_fire.wav" 0.72 \
  "(1-exp(-100*t))*exp(-6*t)*(0.30*sin(2*PI*(86-24*t)*t)+0.09*sin(2*PI*263*t)+0.05*sin(2*PI*887*t))*(1-t/0.72)"
render_wav "$AUDIO_ROOT/weapons/gatling_fire.wav" 0.19 \
  "(1-exp(-180*t))*exp(-20*t)*(0.25*sin(2*PI*118*t)+0.13*sin(2*PI*743*t)+0.08*sin(2*PI*1511*t))*(1-t/0.19)"
render_wav "$AUDIO_ROOT/weapons/sniper_fire.wav" 0.88 \
  "(1-exp(-240*t))*exp(-5.2*t)*(0.34*sin(2*PI*(94-38*t)*t)+0.16*sin(2*PI*611*t)+0.09*sin(2*PI*1783*t))*(1-t/0.88)"
render_wav "$AUDIO_ROOT/weapons/disc_impact.wav" 0.74 \
  "(1-exp(-150*t))*exp(-6*t)*(0.27*sin(2*PI*(310-260*t)*t)+0.13*sin(2*PI*83*t)+0.05*sin(2*PI*1259*t))*(1-t/0.74)"
render_wav "$AUDIO_ROOT/weapons/grenade_impact.wav" 1.18 \
  "(1-exp(-190*t))*exp(-4.2*t)*(0.38*sin(2*PI*(68-21*t)*t)+0.12*sin(2*PI*181*t)+0.065*sin(2*PI*997*t))*(1-t/1.18)"
render_wav "$AUDIO_ROOT/weapons/hitscan_impact.wav" 0.24 \
  "(1-exp(-210*t))*exp(-17*t)*(0.18*sin(2*PI*186*t)+0.10*sin(2*PI*967*t)+0.06*sin(2*PI*1549*t))*(1-t/0.24)"

# Local feedback remains short and spectrally separate from weapons and voice.
render_wav "$AUDIO_ROOT/ui/hit_confirm.wav" 0.20 \
  "(1-exp(-180*t))*exp(-18*t)*(0.20*sin(2*PI*1176*t)+0.10*sin(2*PI*1764*t))*(1-t/0.20)"
render_wav "$AUDIO_ROOT/ui/damage.wav" 0.48 \
  "(1-exp(-100*t))*exp(-7*t)*(0.24*sin(2*PI*(128-70*t)*t)+0.09*sin(2*PI*509*t))*(1-t/0.48)"
render_wav "$AUDIO_ROOT/ui/death.wav" 1.35 \
  "(1-exp(-60*t))*exp(-2.7*t)*(0.20*sin(2*PI*(220-95*t)*t)+0.13*sin(2*PI*(146-52*t)*t)+0.05*sin(2*PI*879*t))*(1-t/1.35)"
render_wav "$AUDIO_ROOT/ui/respawn.wav" 0.80 \
  "(1-exp(-45*t))*exp(-3.8*t)*(0.17*sin(2*PI*(180+310*t)*t)+0.10*sin(2*PI*(270+420*t)*t))*(1-t/0.80)"
render_wav "$AUDIO_ROOT/ui/weapon_switch.wav" 0.18 \
  "(1-exp(-240*t))*exp(-24*t)*(0.18*sin(2*PI*632*t)+0.08*sin(2*PI*1264*t))*(1-t/0.18)"

# Objective cues share a compact harmonic vocabulary so state changes read as
# one system rather than unrelated notification sounds.
render_wav "$AUDIO_ROOT/objective/flag_pickup.wav" 0.72 \
  "(1-exp(-55*t))*exp(-3.8*t)*(0.15*sin(2*PI*294*t)+0.13*sin(2*PI*370*t)+0.11*sin(2*PI*440*t))*(1-t/0.72)"
render_wav "$AUDIO_ROOT/objective/flag_drop.wav" 0.64 \
  "(1-exp(-80*t))*exp(-5*t)*(0.18*sin(2*PI*(260-150*t)*t)+0.10*sin(2*PI*(174-75*t)*t))*(1-t/0.64)"
render_wav "$AUDIO_ROOT/objective/flag_return.wav" 0.76 \
  "(1-exp(-55*t))*exp(-3.6*t)*(0.14*sin(2*PI*220*t)+0.12*sin(2*PI*277*t)+0.10*sin(2*PI*330*t))*(1-t/0.76)"
render_wav "$AUDIO_ROOT/objective/capture.wav" 1.55 \
  "(1-exp(-42*t))*exp(-2.1*t)*(0.15*sin(2*PI*196*t)+0.13*sin(2*PI*247*t)+0.12*sin(2*PI*294*t)+0.08*sin(2*PI*392*t))*(1-t/1.55)"
render_wav "$AUDIO_ROOT/objective/victory.wav" 2.20 \
  "(1-exp(-28*t))*exp(-1.35*t)*(0.14*sin(2*PI*196*t)+0.13*sin(2*PI*247*t)+0.12*sin(2*PI*294*t)+0.10*sin(2*PI*392*t)+0.07*sin(2*PI*494*t))*(1-t/2.20)"
render_wav "$AUDIO_ROOT/objective/defeat.wav" 2.00 \
  "(1-exp(-35*t))*exp(-1.6*t)*(0.16*sin(2*PI*(196-35*t)*t)+0.13*sin(2*PI*(147-24*t)*t)+0.08*sin(2*PI*(98-13*t)*t))*(1-t/2.00)"
render_wav "$AUDIO_ROOT/objective/match_start.wav" 1.10 \
  "(1-exp(-55*t))*exp(-2.7*t)*(0.14*sin(2*PI*(147+80*t)*t)+0.12*sin(2*PI*(220+100*t)*t)+0.08*sin(2*PI*440*t))*(1-t/1.10)"

# Map ambience and adaptive score layers are exact-duration loops. The three
# music files begin together; the director exposes combat and objective stems by
# changing only bus-local volume, so escalation never loses musical phase.
render_loop "$AUDIO_ROOT/ambience/faultline_basin.ogg" 12 \
  "0.055*sin(2*PI*32*t)+0.025*sin(2*PI*64*t)+0.020*(sin(2*PI*191*t)+0.6*sin(2*PI*317*t))*(0.6+0.4*sin(2*PI*t/12))"
render_loop "$AUDIO_ROOT/ambience/cairn_steps.ogg" 12 \
  "0.040*sin(2*PI*49*t)+0.018*sin(2*PI*98*t)+0.024*(sin(2*PI*263*t)+0.55*sin(2*PI*421*t))*(0.65+0.35*sin(2*PI*t/6))"
render_loop "$AUDIO_ROOT/music/exploration.ogg" 12 \
  "(0.070*sin(2*PI*65.4166667*t)+0.052*sin(2*PI*77.8333333*t)+0.045*sin(2*PI*98*t))*(0.72+0.28*sin(2*PI*t/12))"
render_loop "$AUDIO_ROOT/music/combat.ogg" 12 \
  "0.085*sin(2*PI*49*t)*exp(-7*mod(t\,0.5))+0.050*sin(2*PI*196*t)*exp(-10*mod(t\,0.25))+0.032*sin(2*PI*733*t)*exp(-18*mod(t\,0.5))"
render_loop "$AUDIO_ROOT/music/objective.ogg" 12 \
  "0.050*sin(2*PI*294*t)*exp(-4*mod(t\,1.5))+0.045*sin(2*PI*370*t)*exp(-4*mod(t+1\,1.5))+0.040*sin(2*PI*440*t)*exp(-4*mod(t+0.5\,1.5))"

# A browser-playable overview for pull requests and quick reviews. It presents
# ambience, movement, all three score layers, then representative gameplay cues.
ffmpeg -y -hide_banner -loglevel error \
  -i "$AUDIO_ROOT/ambience/faultline_basin.ogg" \
  -i "$AUDIO_ROOT/movement/wind_loop.ogg" \
  -i "$AUDIO_ROOT/music/exploration.ogg" \
  -i "$AUDIO_ROOT/music/combat.ogg" \
  -i "$AUDIO_ROOT/music/objective.ogg" \
  -i "$AUDIO_ROOT/weapons/disc_fire.wav" \
  -i "$AUDIO_ROOT/weapons/disc_impact.wav" \
  -i "$AUDIO_ROOT/weapons/grenade_impact.wav" \
  -i "$AUDIO_ROOT/objective/capture.wav" \
  -i "$AUDIO_ROOT/objective/victory.wav" \
  -filter_complex \
  "[0:a]atrim=0:3.5[a0];[1:a]atrim=0:3.5[a1];[2:a]atrim=0:4[a2];[2:a]atrim=0:4[base3];[3:a]atrim=0:4[hot3];[base3][hot3]amix=inputs=2:normalize=0[a3];[2:a]atrim=0:4[base4];[3:a]atrim=0:4[hot4];[4:a]atrim=0:4[obj4];[base4][hot4][obj4]amix=inputs=3:normalize=0[a4];[a0][a1][a2][a3][a4]concat=n=5:v=0:a=1[bed];[5:a]adelay=15300[s5];[6:a]adelay=16100[s6];[7:a]adelay=17100[s7];[8:a]adelay=18100[s8];[9:a]adelay=19500[s9];[bed][s5][s6][s7][s8][s9]amix=inputs=6:duration=longest:normalize=0,alimiter=limit=0.90:level=false[out]" \
  -map "[out]" -ar "$RATE" -ac 1 -c:a libvorbis -q:a 5 \
  "$AUDIO_ROOT/preview/audio_foundation_sampler.ogg"

(
  cd "$AUDIO_ROOT"
  sha256sum \
    ambience/*.ogg movement/*.ogg movement/*.wav music/*.ogg \
    objective/*.wav preview/*.ogg ui/*.wav weapons/*.wav \
    | sort -k 2 > SHA256SUMS
)

echo "Generated audio library at $AUDIO_ROOT"
