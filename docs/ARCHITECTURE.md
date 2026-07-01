# Architecture

Arrow Escape is organized by runtime responsibility rather than by a single monolithic scene.

## Composition

`Main` owns screen composition and responds to navigation requests. `Home` and `Game` are disposable feature screens. `Board` is a reusable gameplay component: it accepts level data, owns arrow interactions, and emits outcomes without reading or writing progression.

## Services

- `GameManager` owns the active run state and coordinates navigation, scoring, completion, and restart behavior.
- `LevelManager` is a pure deterministic level source. Its center-out construction creates a guaranteed reverse-removal solution.
- `SaveManager` owns schema defaults, migration, validation, backup recovery, and atomic replacement of local JSON data.
- `AudioManager` owns buses, persisted mute state, music playback, and a small sound-effect player pool.

Dependencies flow from scenes toward services. Services never depend on scene paths or UI nodes. The Board reports intent to the Game scene, and the Game scene forwards domain events to `GameManager`.

## Persistence boundary

Only `SaveManager` accesses `user://`. Callers use semantic operations such as `update_progress` and `set_setting`; they do not mutate files. Saves carry an explicit version and are merged with current defaults on load so additive migrations remain safe.

## Rewarded-ad boundary

Rewarded ads require a native Android SDK, so vendor code must remain in an audited prebuilt Godot Android plugin. A future `AdManager` will expose availability, presentation, reward, close, and failure signals. Its provider adapter will translate native callbacks, and rewards will be issued only after the native verified-reward callback. Gameplay and saving will not import or call vendor APIs directly.

The offline game loop never waits for an ad. If the SDK, network, consent, or inventory is unavailable, the reward action is unavailable and progression continues normally.

## Testing strategy

`tests/test_level_generation.gd` simulates the generated solution for the first 64 levels. Headless project startup additionally compiles all autoloads and scene scripts. Android release verification should add physical-device lifecycle, safe-area, save-recovery, and native ad callback tests.
