# DRIVER HUD 1.4.1 — Validation

1.4.1 formalizes the 1.4.0-HF1 code path after live smoke testing confirmed the tank HUD displays again. The fresh HF1 Arsenal GUID is intentionally retained so 1.4.1 upgrades the tested entry instead of creating another identity.

## Scope

- Runtime version markers and manifest metadata updated to 1.4.1.
- Reload indicator placement remains left of the reloadable weapon icon.
- 1.4.0 tank telemetry/runtime architecture is unchanged.
- External bilingual FRV TXT configuration is unchanged.
- No 20 Hz probe loops, world scans, or guessed targeted getters were introduced.

## Automated checks

The repository includes focused release metadata checks, tank/FRV integration tests, robustness tests, performance-contract tests, position-TXT tests, capture replay, Win32 adapter tests, and binary package validation. See `evidence/` for the outputs generated with this source snapshot.

The automated environment is not a substitute for exhaustive live multiplayer/FPS testing.
