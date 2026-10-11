# Development

## Environment

The project was validated with the standard GDScript build of Godot **4.7.2** on Windows, using Forward+ and Direct3D 12. Open `project.godot` and run the main scene with F5. No addon is required. Other operating systems, graphics backends and earlier Godot versions need separate validation.

The scene is generated at runtime from a fixed seed. An empty-looking editor viewport before F5 is normal. Glyphs use a system font fallback chain (Consolas, DejaVu Sans Mono, monospace); platform differences can affect appearance.

## Command-line checks

These examples assume the Godot executable is on PATH as `godot` and the working directory is the repository root. Substitute the full executable path if needed.

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/run_locomotion.gd
```

The runner loads the real clearing, disables ordinary frame input processing, runs the existing probe and exits with a nonzero status on failure. It checks planted-foot drift, foot height, lower-leg length, idle and blocked movement, and reflected joint transforms. A headless pass does **not** validate shader appearance or GPU performance.

### Manual visual pass

1. Run with graphics enabled and inspect the arch, grass and pond from two camera angles.
2. Use F to compare the surface rendering and +/- to change glyph size.
3. Switch between the three grass densities.
4. Walk and run; stop, turn, approach a blocker and cross the shoreline.
5. Use C to inspect feet, knees, cape, lantern and the reflected pose.
6. Check the debugger and record any new errors with the reproduction steps.

## Optional local tools

Godot AI MCP was used during development but is not needed to run or test this repository. Optional editor addons and machine-specific settings are excluded from Git. Install tools from their own upstream sources and enable them locally in Project Settings > Plugins. Do not commit those plugin or autoload entries to the public `project.godot`.

Godot supports a local `override.cfg` for runtime project settings; it is ignored here. Editor plugin activation still needs to be handled in the editor. See the official [ProjectSettings documentation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html).

With Godot AI connected to a running game, the original probe can also be invoked through `game_eval`:

```gdscript
return load("res://tests/locomotion_probe.gd").new().run_checks(get_tree().current_scene)
```

## Public repository boundaries

Commit original source, `.uid` files, documentation and project screenshots. Generated imports, `.godot`, export credentials, local tool configuration, engine executables and third-party reference images stay out of version control. The initial publication of the source does not include packaged binaries or server infrastructure.
