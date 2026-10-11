# Contributing to Blackwater

The current priority is a readable, atmospheric ASCII world and a convincing moving character. Small improvements with clear before/after evidence are especially useful.

## Start here

1. Run the project using the [README](README.md).
2. Read the [architecture](docs/ARCHITECTURE.md) and [roadmap](docs/ROADMAP.md).
3. For a large feature or a new dependency, open an issue first so the direction can be discussed.
4. Keep each pull request focused on one concern.

## What to include

- Explain the problem and the resulting behavior.
- For visual changes, include comparable before/after screenshots, camera settings and renderer information.
- For movement changes, run the locomotion probe described in [Development](docs/DEVELOPMENT.md), then inspect turns, starts and stops in-game.
- State the Godot version, operating system, GPU and checks performed. Mention anything untested.
- Keep the public project runnable without editor plugins. Do not commit caches, local overrides, credentials, downloaded binaries or third-party reference screenshots.

Use tabs for GDScript indentation and UTF-8 text. Preserve the sparse dark areas, material-specific glyphs and legible silhouettes. Avoid adding a dependency for a change that fits the existing code.

## Assets and licensing

Only submit work you have the right to contribute. Contributions are made under this repository's MIT License. Identify any third-party sources and their licenses; do not copy assets, characters or code from visual references.

Bug reports and visual feedback are welcome in English or Italian. Be constructive and discuss the work respectfully.
