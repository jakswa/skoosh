# SKOOSH agent handoff

- Godot 4.4+, typed GDScript, Compatibility renderer; native clients + Linux headless server. No browser target.
- Read `docs/CHECKPOINT.md` first; plans/decisions are linked there.
- Run/hosting/export: `README.md` and `docs/PLAYTESTING_AND_DISTRIBUTION.md`.
- Network invariant: server owns movement results, energy, combat, objectives, and score.
- Multiplayer entry: `scenes/network_demo.tscn`; preserved solo entry: `scenes/main.tscn`.
- Validate with `tools/test_ground_jet.sh` and `tools/test_multiplayer_demo.sh`.
- Prefer headless checks; launch graphical clients only when requested.
- Visual/UX work: run the desktop-safe off-screen loop in `docs/VISUAL_QA.md`.
