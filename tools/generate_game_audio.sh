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
  local seed="$3"
  local color="$4"
  local noise_filter="$5"
  local expression="$6"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "anoisesrc=r=$RATE:d=$duration:a=1:c=$color:s=$seed" \
    -f lavfi -i "aevalsrc=exprs='$expression':s=$RATE:d=$duration" \
    -filter_complex \
    "[0:a]$noise_filter[noise];[noise][1:a]amix=inputs=2:normalize=0,highpass=f=22,afade=t=out:st=0:d=$duration:curve=tri,volume=0.72,alimiter=limit=0.82:level=false[out]" \
    -map "[out]" -ar "$RATE" -ac 1 -c:a pcm_s16le "$output"
}

# Circularly crossfade deterministic noise so broadband loops do not click at
# their wrap point. Tonal layers use periods that divide the rendered length.
render_loop() {
  local output="$1"
  local duration="$2"
  local seed="$3"
  local color="$4"
  local noise_filter="$5"
  local expression="$6"
  local wrap=0.5
  local source_duration="${duration}.5"
  ffmpeg -y -hide_banner -loglevel error \
    -f lavfi -i "anoisesrc=r=$RATE:d=$source_duration:a=1:c=$color:s=$seed" \
    -f lavfi -i "aevalsrc=exprs='$expression':s=$RATE:d=$duration" \
    -filter_complex \
    "[0:a]$noise_filter[colored];[colored]asplit=3[n0][n1][n2];[n0]atrim=start=0:end=$wrap,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=$wrap[a];[n1]atrim=start=$duration:end=$source_duration,asetpts=PTS-STARTPTS,afade=t=out:st=0:d=$wrap[b];[a][b]amix=inputs=2:normalize=0[edge];[n2]atrim=start=$wrap:end=$duration,asetpts=PTS-STARTPTS[rest];[edge][rest]concat=n=2:v=0:a=1[noise];[noise][1:a]amix=inputs=2:normalize=0,highpass=f=22,alimiter=limit=0.78:level=false[out]" \
    -map "[out]" -ar "$RATE" -ac 1 -c:a libvorbis -q:a 5 "$output"
}

# Movement is mostly filtered air and surface texture. Quiet resonances supply
# identity without turning continuous motion into an exposed oscillator.
render_loop "$AUDIO_ROOT/movement/wind_loop.ogg" 12 101 pink \
  "highpass=f=170,lowpass=f=10500,volume='0.28*(0.76+0.16*sin(2*PI*t/12)+0.08*sin(2*PI*t/3))':eval=frame" \
  "0.008*sin(2*PI*96*t)*(0.6+0.4*sin(2*PI*t/12))"
render_loop "$AUDIO_ROOT/movement/ski_loop.ogg" 8 102 velvet \
  "highpass=f=280,lowpass=f=6200,volume='0.13*(0.72+0.18*sin(2*PI*t/2)+0.10*sin(2*PI*t/0.8))':eval=frame" \
  "0.018*sin(2*PI*92*t)+0.008*sin(2*PI*184*t)"
render_loop "$AUDIO_ROOT/movement/jet_loop.ogg" 6 103 brown \
  "highpass=f=38,lowpass=f=4200,volume='0.30*(0.86+0.08*sin(2*PI*t/1.5)+0.06*sin(2*PI*t/0.5))':eval=frame" \
  "0.075*sin(2*PI*72*t)+0.025*sin(2*PI*144*t)+0.008*sin(2*PI*432*t)"
render_wav "$AUDIO_ROOT/movement/land.wav" 0.38 201 brown \
  "lowpass=f=1500,volume='0.62*exp(-11*t)':eval=frame" \
  "0.30*sin(2*PI*(74*t-38*t*t))*exp(-12*t)"
render_wav "$AUDIO_ROOT/movement/jet_empty.wav" 0.32 202 pink \
  "highpass=f=420,lowpass=f=6200,volume='0.24*exp(-9*t)':eval=frame" \
  "0.13*sin(2*PI*(520*t-700*t*t))*exp(-8*t)"

# Weapons combine a broadband transient, a low mechanical body, and a short
# tail. The corrected phase equations describe the intended linear sweeps.
render_wav "$AUDIO_ROOT/weapons/disc_fire.wav" 0.46 301 white \
  "highpass=f=650,lowpass=f=10500,volume='0.48*exp(-24*t)+0.06*exp(-5*t)':eval=frame" \
  "0.21*sin(2*PI*(115*t+325*t*t))*exp(-6*t)+0.11*sin(2*PI*(62*t+70*t*t))*exp(-8*t)"
render_wav "$AUDIO_ROOT/weapons/grenade_fire.wav" 0.44 302 brown \
  "highpass=f=45,lowpass=f=2400,volume='0.48*exp(-13*t)':eval=frame" \
  "0.29*sin(2*PI*(88*t-24*t*t))*exp(-9*t)+0.07*sin(2*PI*310*t)*exp(-18*t)"
render_wav "$AUDIO_ROOT/weapons/gatling_fire.wav" 0.105 303 white \
  "highpass=f=500,lowpass=f=11000,volume='0.52*exp(-48*t)':eval=frame" \
  "0.25*sin(2*PI*108*t)*exp(-34*t)"
render_wav "$AUDIO_ROOT/weapons/sniper_fire.wav" 0.58 304 white \
  "highpass=f=180,lowpass=f=12000,volume='0.58*exp(-34*t)+0.07*exp(-5*t)':eval=frame" \
  "0.34*sin(2*PI*(86*t-22*t*t))*exp(-7*t)+0.08*sin(2*PI*258*t)*exp(-14*t)"
render_wav "$AUDIO_ROOT/weapons/disc_impact.wav" 0.52 305 pink \
  "highpass=f=130,lowpass=f=7600,volume='0.50*exp(-18*t)+0.08*exp(-5*t)':eval=frame" \
  "0.20*sin(2*PI*(240*t-210*t*t))*exp(-8*t)+0.10*sin(2*PI*78*t)*exp(-7*t)"
render_wav "$AUDIO_ROOT/weapons/grenade_impact.wav" 0.92 306 brown \
  "highpass=f=32,lowpass=f=5200,volume='0.66*exp(-11*t)+0.11*exp(-3.8*t)':eval=frame" \
  "0.38*sin(2*PI*(64*t-18*t*t))*exp(-6*t)+0.09*sin(2*PI*128*t)*exp(-9*t)"
render_wav "$AUDIO_ROOT/weapons/hitscan_impact.wav" 0.16 307 white \
  "highpass=f=700,lowpass=f=11500,volume='0.46*exp(-42*t)':eval=frame" \
  "0.13*sin(2*PI*174*t)*exp(-25*t)"

# Local feedback is deliberately dry and brief so repeated combat events do not
# build into piercing, phase-aligned stacks.
render_wav "$AUDIO_ROOT/ui/hit_confirm.wav" 0.075 401 velvet \
  "highpass=f=1300,lowpass=f=7600,volume='0.18*exp(-55*t)':eval=frame" \
  "0.09*sin(2*PI*880*t)*exp(-42*t)"
render_wav "$AUDIO_ROOT/ui/damage.wav" 0.30 402 pink \
  "highpass=f=70,lowpass=f=2600,volume='0.34*exp(-13*t)':eval=frame" \
  "0.18*sin(2*PI*(125*t-58*t*t))*exp(-9*t)"
render_wav "$AUDIO_ROOT/ui/death.wav" 0.90 403 brown \
  "highpass=f=35,lowpass=f=2100,volume='0.27*exp(-4.5*t)':eval=frame" \
  "0.19*sin(2*PI*(180*t-62*t*t))*exp(-3.4*t)+0.08*sin(2*PI*(120*t-34*t*t))*exp(-3.8*t)"
render_wav "$AUDIO_ROOT/ui/respawn.wav" 0.58 404 pink \
  "highpass=f=700,lowpass=f=6500,volume='0.12*(1-exp(-20*t))*exp(-4.8*t)':eval=frame" \
  "0.12*sin(2*PI*(196*t+105*t*t))*exp(-4.8*t)+0.08*sin(2*PI*(294*t+135*t*t))*exp(-5.2*t)"
render_wav "$AUDIO_ROOT/ui/weapon_switch.wav" 0.09 405 velvet \
  "highpass=f=500,lowpass=f=6800,volume='0.24*exp(-48*t)':eval=frame" \
  "0.09*sin(2*PI*330*t)*exp(-38*t)"

# Objective cues use one C-minor vocabulary, but articulate it as short phrases
# instead of exposing static organ-like chords.
render_wav "$AUDIO_ROOT/objective/flag_pickup.wav" 0.58 501 pink \
  "highpass=f=900,lowpass=f=5200,volume='0.055*exp(-7*t)':eval=frame" \
  "0.15*between(t\,0\,0.24)*sin(2*PI*261.63*t)*exp(-8*t)+0.13*between(t\,0.14\,0.40)*sin(2*PI*311.13*(t-0.14))*exp(-8*(t-0.14))+0.11*between(t\,0.29\,0.58)*sin(2*PI*392*(t-0.29))*exp(-7*(t-0.29))"
render_wav "$AUDIO_ROOT/objective/flag_drop.wav" 0.48 502 brown \
  "highpass=f=80,lowpass=f=1800,volume='0.18*exp(-9*t)':eval=frame" \
  "0.15*between(t\,0\,0.30)*sin(2*PI*261.63*t)*exp(-7*t)+0.13*between(t\,0.16\,0.48)*sin(2*PI*196*(t-0.16))*exp(-6*(t-0.16))"
render_wav "$AUDIO_ROOT/objective/flag_return.wav" 0.62 503 pink \
  "highpass=f=700,lowpass=f=4800,volume='0.045*exp(-6*t)':eval=frame" \
  "0.15*between(t\,0\,0.34)*sin(2*PI*196*t)*exp(-6*t)+0.13*between(t\,0.20\,0.62)*sin(2*PI*261.63*(t-0.20))*exp(-5*(t-0.20))"
render_wav "$AUDIO_ROOT/objective/capture.wav" 1.28 504 pink \
  "highpass=f=500,lowpass=f=5200,volume='0.055*exp(-3.2*t)':eval=frame" \
  "0.14*between(t\,0\,0.42)*sin(2*PI*261.63*t)*exp(-5*t)+0.13*between(t\,0.23\,0.70)*sin(2*PI*311.13*(t-0.23))*exp(-5*(t-0.23))+0.12*between(t\,0.48\,0.96)*sin(2*PI*392*(t-0.48))*exp(-4.5*(t-0.48))+0.10*between(t\,0.74\,1.28)*sin(2*PI*523.25*(t-0.74))*exp(-4*(t-0.74))"
render_wav "$AUDIO_ROOT/objective/victory.wav" 1.85 505 pink \
  "highpass=f=400,lowpass=f=5800,volume='0.05*exp(-2.4*t)':eval=frame" \
  "0.14*between(t\,0\,0.58)*sin(2*PI*261.63*t)*exp(-4*t)+0.13*between(t\,0.30\,0.88)*sin(2*PI*311.13*(t-0.30))*exp(-4*(t-0.30))+0.12*between(t\,0.62\,1.22)*sin(2*PI*392*(t-0.62))*exp(-3.8*(t-0.62))+0.11*between(t\,0.96\,1.85)*sin(2*PI*523.25*(t-0.96))*exp(-2.8*(t-0.96))"
render_wav "$AUDIO_ROOT/objective/defeat.wav" 1.55 506 brown \
  "highpass=f=45,lowpass=f=1600,volume='0.12*exp(-3*t)':eval=frame" \
  "0.15*between(t\,0\,0.55)*sin(2*PI*261.63*t)*exp(-4*t)+0.13*between(t\,0.30\,0.92)*sin(2*PI*233.08*(t-0.30))*exp(-3.8*(t-0.30))+0.11*between(t\,0.68\,1.55)*sin(2*PI*196*(t-0.68))*exp(-3*(t-0.68))"
render_wav "$AUDIO_ROOT/objective/match_start.wav" 0.92 507 pink \
  "highpass=f=600,lowpass=f=5200,volume='0.045*exp(-4*t)':eval=frame" \
  "0.14*between(t\,0\,0.35)*sin(2*PI*130.81*t)*exp(-5*t)+0.12*between(t\,0.22\,0.62)*sin(2*PI*196*(t-0.22))*exp(-5*(t-0.22))+0.10*between(t\,0.48\,0.92)*sin(2*PI*261.63*(t-0.48))*exp(-4.5*(t-0.48))"

# All score stems remain sample-aligned and share C, E-flat, G, and B-flat. The
# extra stems add pulse and motion rather than unrelated harmonic information.
render_loop "$AUDIO_ROOT/ambience/faultline_basin.ogg" 12 601 brown \
  "highpass=f=28,lowpass=f=1900,volume='0.13*(0.78+0.14*sin(2*PI*t/12)+0.08*sin(2*PI*t/4))':eval=frame" \
  "0.025*sin(2*PI*32*t)+0.009*sin(2*PI*64*t)"
render_loop "$AUDIO_ROOT/ambience/cairn_steps.ogg" 12 602 pink \
  "highpass=f=110,lowpass=f=5200,volume='0.10*(0.76+0.16*sin(2*PI*t/6)+0.08*sin(2*PI*t/3))':eval=frame" \
  "0.018*sin(2*PI*49*t)+0.006*sin(2*PI*98*t)"
render_loop "$AUDIO_ROOT/music/exploration.ogg" 12 603 pink \
  "highpass=f=120,lowpass=f=1800,volume='0.06*(0.58+0.42*sin(2*PI*t/12))':eval=frame" \
  "(0.11*sin(2*PI*65.4166667*t)+0.05*sin(2*PI*98*t)+0.03*sin(2*PI*155.5833333*t))*(0.72+0.28*sin(2*PI*t/12))"
render_loop "$AUDIO_ROOT/music/combat.ogg" 12 604 brown \
  "highpass=f=48,lowpass=f=2100,volume='0.34*exp(-9*mod(t\,0.75))+0.05':eval=frame" \
  "0.15*sin(2*PI*65.4166667*t)*exp(-8*mod(t\,0.75))+0.055*sin(2*PI*130.8333333*t)*exp(-10*mod(t\,0.375))+0.035*sin(2*PI*196*t)*exp(-12*mod(t\,0.75))"
render_loop "$AUDIO_ROOT/music/objective.ogg" 12 605 pink \
  "highpass=f=500,lowpass=f=3600,volume='0.055*(0.7+0.3*sin(2*PI*t/3))':eval=frame" \
  "0.10*sin(2*PI*261.6666667*t)*exp(-5*mod(t\,3))+0.08*sin(2*PI*311.1666667*t)*exp(-5*mod(t+2.25\,3))+0.07*sin(2*PI*392*t)*exp(-5*mod(t+1.5\,3))+0.06*sin(2*PI*466.1666667*t)*exp(-5*mod(t+0.75\,3))"

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
