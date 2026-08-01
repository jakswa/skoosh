# Voice command assets

The quick-command clips under `audio/voice/` were generated on 2026-08-01 with Cartesia's public Jace stock voice (`6776173b-fd72-460d-89b3-d85812ee518d`) and the pinned `sonic-3.5-2026-05-04` model snapshot. The recordings do not imitate or reuse a performer or another game's audio.

Regenerate the normalized mono 44.1 kHz WAV files with:

```bash
./tools/generate_voice_commands.sh
```

The script reads `CARTESIA_API_KEY` from the ignored `.env` file by default. The key is an offline production input and must never be embedded in a client export or committed.

Generation uses speed `1.08`, then normalizes each clip to mono signed 16-bit PCM at 44.1 kHz and approximately -18 LUFS. Current service terms are at <https://cartesia.ai/legal/terms> and pricing/license details are at <https://cartesia.ai/pricing>.

Before distribution, confirm that the Cartesia account tier and current terms permit the intended use of generated output. Preserve the generation date, model ID, voice ID, account tier, and applicable terms with release records.

## SHA-256

```text
38f35c81fa1a6d016ea1d325af95c8d27d7f631a0939b7798f2838843ad31a0d  all_clear.wav
50636a9323048e67e4cc6b45e5e5d20975faa5fe6e77740edc117aeee1bbb03e  cover_my_return.wav
633e6d5c94da9c023d16a6a7cde7d018e40f9bedb71f23f0d3dc8c294442c415  defend_our_standard.wav
4fc1b2100b9aa18bb129bddc214dfe3d2d7cde31927f0861a3ea3f5e92f7a936  goodbye.wav
abf2f6c6347e76d61a774bf961adf041c1f008f6422761e7d4cbacda125e44f5  hello.wav
17f502c339e781a86c600991d00d424fdd3a67afa70cf9f1e7771161b73a1f54  need_support.wav
53db897f7a6f51cc74cdbf11a70525cdc94d77ed9becb97e3f21c79fa703a2bb  no.wav
063d09742c7e3919849505ea713a8deebba5d8a75686c44159a4abee33fbc92c  push_far_platform.wav
44eda2cbf895c980a1b576e8f5c1ccccad8276b4fe4e67c82eaf939e7680794f  recover_our_standard.wav
9f2d570bf56e6d562d30e069d74207f8da8e17b1fe51af0c5cb72c61e9134bfa  shazbot.wav
d6276a36f613788f6708c7a2710bfeb40b6fb426f474c2b96d40f7138c7c96bc  thanks.wav
fce1bf9680bb5364b4ed53a0f1c9cb8605db1987504192eaa65e6a14e5ba6767  yes.wav
```
