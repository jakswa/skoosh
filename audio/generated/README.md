# Generated game audio

This directory contains SKOOSH's initial movement, combat, objective, ambience,
and adaptive-score library. Every asset is rendered from mathematical
oscillators by `tools/generate_game_audio.sh`; no recordings, sample packs,
music libraries, generative-AI services, or third-party source material are
used.

Regenerate the complete library and audition montage with:

```bash
./tools/generate_game_audio.sh
```

The committed `SHA256SUMS` is an integrity record for the checked-in renders.
PCM WAV output is byte-reproducible with the pinned recipe. Ogg audio content is
reproducible, but container serial numbers can produce different hashes across
otherwise identical renders or FFmpeg/libvorbis versions.

## Format and use

- One-shots: mono 48 kHz 16-bit PCM WAV.
- Loops: mono 48 kHz Ogg Vorbis, enabled for looping at runtime.
- Music: three phase-aligned 12-second stems for exploration, combat, and
  objective pressure.
- Preview: `preview/audio_foundation_sampler.ogg` sequences ambience, wind,
  adaptive music layers, weapon impacts, capture, and victory cues.

These are original project renders with complete in-repository provenance.
They are placeholders intended to establish mix behavior and can be replaced
one-for-one by commissioned or separately licensed production assets later.
