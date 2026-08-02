# Voice command assets

The quick-command cast under `audio/voice/` was generated on 2026-08-02 from five Cartesia stock voices using the pinned `sonic-3.5-2026-05-04` model snapshot:

| Pack | Cartesia stock voice | Voice ID |
| --- | --- | --- |
| `zack` | Zack — Sportsman | `ed81fd13-2016-4a49-8fe3-c0d2761695fc` |
| `renee` | Renee — Commander | `c2ac25f9-ecc4-4f56-9095-651354df60c0` |
| `clint` | Clint — Rugged Actor | `db69127a-dbaf-4fa9-b425-2fe67680c348` |
| `brittany` | Brittany — Intense Performer | `46788d8e-cdf9-4d5c-9125-094eb2e4d44c` |
| `jasper` | Jasper — Vibrant Stylist | `e98bd614-9b9d-4031-b930-ed72482af858` |

These voices were selected for varied, energetic delivery. They do not imitate or reuse a performer or another game's audio. A player's randomized ENet peer ID deterministically selects their voice pack for the connection, so every listener resolves the same voice without replicating another property.

Regenerate all 60 processed mono 11.025 kHz unsigned 8-bit PCM WAV files with:

```bash
./tools/generate_voice_commands.sh
```

Regenerate only selected packs or clips with comma-separated filters:

```bash
SKOOSH_VOICE_PACKS=zack,renee ./tools/generate_voice_commands.sh
SKOOSH_VOICE_CLIPS=defend_our_flag,recover_our_flag ./tools/generate_voice_commands.sh
```

The script reads `CARTESIA_API_KEY` from the ignored `.env` file by default, or from the existing environment. The key is an offline production input and must never be embedded in a client export or committed.

Generation uses speed `1.12` and short, exclamatory transcripts. FFmpeg then applies a restrained radio treatment: 280–3600 Hz communications-band filtering, a 1.7 kHz presence lift, compression, mild bit/sample crushing, and normalization to approximately -16 LUFS. Final delivery at 11.025 kHz unsigned 8-bit PCM deliberately contributes period-appropriate bandwidth and quantization grain while reducing the 60-clip cast from about 5.38 MB at 44.1 kHz/16-bit to about 0.68 MB. Source audio is kept only in temporary ignored files.

`audio/voice/SHA256SUMS` records the generated asset hashes and is refreshed by the generation script. Verify it with:

```bash
(cd audio/voice && sha256sum --check SHA256SUMS)
```

Current service terms are at <https://cartesia.ai/legal/terms> and pricing/license details are at <https://cartesia.ai/pricing>. Before distribution, confirm that the Cartesia account tier and current terms permit the intended use of generated output. Preserve the generation date, model ID, voice IDs, account tier, and applicable terms with release records.
