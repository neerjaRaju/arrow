# Arrow Escape

Arrow Escape is an offline-first portrait puzzle game for Android. Tap an arrow when its path to the edge is clear. Remove every arrow to complete the level; blocked arrows stay on the board and count as a miss.

This repository targets **Godot 4.5.1**, uses **GDScript only**, and has no server dependency. Progress and preferences are stored locally in `user://arrow_escape_save.json`.

## Milestone 1 foundation

- Responsive 720 × 1280 portrait UI with safe-area-aware screens
- Main, Home, Game, and reusable Board scenes
- Deterministic, solvable procedural levels with seeded progression
- Versioned and recoverable local JSON saves
- Session, navigation, level, and audio autoload managers
- Android Gradle export preset for ARM64, API 24–35
- Rewarded-ad integration boundary documented for a later Android plugin milestone
- Production grid engine for 5x5–10x10 boards with touch selection and JSON snapshots
- Catmull-Rom snake engine with pooled body segments, smooth head-first movement, and AnimationTree integration
- Collision engine with snake/wall/boundary checks, cell reservations, no-overlap/no-crossing validation, exits, and debugger overlay
- Mobile touch controller with tap, drag, swipe, selection/deselection, single-touch enforcement, input buffering, and pooled ripple effects

## Project layout

```text
autoload/       Cross-scene state, persistence, audio, and level services
assets/         Source-controlled icons and future game assets
scenes/         Main, home, game, and board scene composition
scripts/        Scene behavior, grouped by feature
addons/         Reserved for audited Godot Android plugins
docs/           Architecture and integration notes
```

## Run locally

1. Install Godot 4.5.1 with Android build support.
2. Import `project.godot` from the Godot Project Manager.
3. Run the project. Desktop execution is supported for development; release exports are Android-only.

## Android release setup

1. Install the Android SDK/JDK versions required by Godot 4.5.1 and configure them under **Editor Settings → Export → Android**.
2. Install the Godot Android build template from **Project → Install Android Build Template**.
3. Create a release keystore outside the repository and configure its path, alias, and passwords in the local Android export settings.
4. Export an AAB for Play distribution by changing `gradle_build/export_format` to `1` locally or through the export UI.

The committed preset intentionally contains no signing secrets. Internet and network-state permissions are present solely for the future rewarded-ad provider; game progression remains fully offline.

## Rewarded ads

The gameplay reward flow will be mediated by an `AdManager` and a provider adapter so game code never depends on a vendor SDK. The Android provider must use an audited Godot 4.x Android plugin and grant rewards only from the SDK's verified reward callback. No fake reward or development fallback is shipped in this milestone.

## Quality checks

```bash
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 5
godot --headless --path . --scene res://tests/grid/GridEngineUnitTest.tscn
godot --headless --path . --scene res://tests/snake/SnakeEngineUnitTest.tscn
godot --headless --path . --scene res://tests/collision/CollisionEngineUnitTest.tscn
godot --headless --path . --scene res://tests/input/TouchInputUnitTest.tscn
```

For a release, also export a signed AAB and test install, local save recovery, audio persistence, lifecycle pause/resume, and rewarded-ad callbacks on a physical Android device.

## License

Copyright © 2026 neerjaRaju. All rights reserved.
