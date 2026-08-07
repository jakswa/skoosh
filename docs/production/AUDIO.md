# Audio foundation

The client audio system gives SKOOSH a persistent, adaptive soundscape across
movement, combat, objectives, and the two production maps. The implementation on
`main` is the current client-presentation audio baseline. This page is the owning
production reference; the in-repository render index with regeneration commands
is `audio/generated/README.md`.

## Scope

The audio director (`scripts/client_audio.gd`) is client-only and no-ops in
headless/server runs. It drives:

- **Movement loops:** speed-scaled wind, ski, and jet loops with pitch tracking,
  plus landing and jet-empty one-shots.
- **Map ambience:** a per-map layer for Faultline Basin and Cairn Steps.
- **Adaptive score:** three phase-aligned stems (exploration, combat, objective)
  crossfaded by combat heat and objective pressure. The score sits on a quiet
  floor so nothing plays until in-match pressure justifies it.
- **Weapons:** positional fire and impact for all four slots.
- **UI feedback:** hit confirmation, damage, death, respawn, weapon switch.
- **Objectives:** flag pickup/drop/return, capture, match start, victory/defeat.
- **Remote players:** a bounded 32-slot positional pool for 3D panning.

All event cues are generation-gated so stale audio from a retired map world is
rejected, matching the rotation seam.

## Mixer

`default_bus_layout.tres` defines seven buses: **Master**, **Music**,
**Ambience**, **SFX**, **Movement** (→ SFX), **UI**, and **Voice**. The Master
bus has an output limiter; the Music bus has a voice-to-music ducking compressor
so radio calls cut over the score. Buses and the limiter/ducking effects are
checked by the audio contract test.

## Provenance

Every generated asset is rendered from seeded noise, filters, envelopes, and
mathematical oscillators by `tools/generate_game_audio.sh` using FFmpeg. No
recordings, sample packs, music libraries, generative-AI services, or
third-party source material are used.

- One-shots: mono 48 kHz 16-bit PCM WAV.
- Loops: mono 48 kHz Ogg Vorbis, loop-enabled at runtime.
- Music: three sample-aligned 12-second stems.
- Preview montage: `preview/audio_foundation_sampler.ogg`.

`audio/generated/SHA256SUMS` is the integrity record for committed renders. PCM
WAV output is byte-reproducible; Ogg container serials can produce different
hashes across identical renders or tool versions.

## Regeneration

```bash
./tools/generate_game_audio.sh
```

Run it after changing the generator, then allow Godot to reimport before
capture. Committed renders are placeholders intended to establish mix behavior
and can be replaced one-for-one by commissioned or separately licensed
production assets later.

## Validation

- `./tools/test_client_audio.sh` checks all 29 runtime assets exist, are
  readable, match the WAV/bus contract, verify the three music stems are
  phase-aligned, verify the combat response is bounded and monotonic, and confirm
  the director no-ops in headless runs.
- The contract is part of the bounded fast headless suite.
- Generated audio is excluded from dedicated-server exports.

## Remaining qualification

Automated checks validate asset and bus integration, not subjective mix quality.
Final mix levels, loudness, and balance still need a human gameplay/listening
pass across real matches. Audition the
[21.7-second foundation sampler](../../audio/generated/preview/audio_foundation_sampler.ogg)
before tuning the mix.
