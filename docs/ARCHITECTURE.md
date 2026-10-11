# Rendering and locomotion

Blackwater is currently a single Godot scene assembled by `scripts/glade.gd`. It is an art and movement study, not an MMO backend or a general-purpose engine.

## Frame pipeline

1. `glyph_atlas.gd` draws 96 glyph slots into a 320 × 192 atlas using a system monospace font.
2. After the first rendered frame, the atlas is read back once, mipmaps are generated and the atlas viewport stops updating.
3. A 1440 × 900 `SubViewport` renders the orthographic world.
4. A second, half-resolution viewport renders a mirrored copy of selected geometry for the water.
5. A canvas pass adds the vignette. The interface is drawn separately.

## A different alphabet for each material

`surface_glyphs.gdshader` projects the atlas in local object coordinates, selecting a plane from the dominant surface normal. Stone, foliage, cloth and metal use different glyphs and scales. Normal 3D lighting gives the marks volume; a small continuous fill preserves dark silhouettes.

`grass.gdshader` renders MultiMesh cards with slash, backslash and vertical-bar glyphs. The cards face the camera, remain rooted in the scene and sway in the vertex shader. Patchy placement, density controls and clear paths keep the ground from becoming uniform visual noise.

`ground.gdshader` provides the almost-black soil beneath those marks. `water.gdshader` samples the mirrored view, decodes its color, adds distortion and sparse horizontal glyphs, and draws stylized ripples around the player.

The old full-screen grid is kept in `legacy_ascii.gdshader` for historical comparison and is unused. `weathered.gdshader` is also a legacy experiment. The active `ascii.gdshader` is the final vignette pass.

## Reflections

The mirrored scene includes the ruins, trees and wanderer, with simplified mirrored lighting. Grass and motes are excluded. Joint transforms are copied into the reflected character after animation. This is a scene-specific planar technique, not general ray-traced reflection or physically simulated water.

## Character motion

`wanderer_rig.gd` builds a segmented figure from procedural geometry. Locomotion advances with actual displacement, so pushing against an obstacle does not advance the walk cycle. Each leg has a stance and swing phase:

- During stance, the foot stays at its world-space anchor.
- During swing, the foot follows an arc toward the next step.
- A two-segment solution places the knee and lower leg.

Idle breathing, body motion, arm swing, cape motion and the lantern complete the pose. Walk/run blending follows speed. The floor model currently distinguishes the clearing from the shallow pond; it does not solve arbitrary slopes or stairs. Collision uses simple circular blockers around trunks and masonry.

## Source map

| Path | Responsibility |
| --- | --- |
| `scenes/glade.tscn` | Minimal entry scene |
| `scripts/glade.gd` | Scene construction, camera, input, movement, lighting, reflection and UI |
| `scripts/glyph_atlas.gd` | Runtime glyph atlas |
| `scripts/wanderer_rig.gd` | Procedural character geometry and animation |
| `shaders/` | Surface, grass, soil, water and compositing shaders |
| `tests/locomotion_probe.gd` | Numerical locomotion checks |
| `tests/run_locomotion.gd` | Standalone command-line runner |

## Current limits

The internal render size is fixed. System font selection can change the appearance between machines. Tiny glyphs can alias, tree silhouettes need variety, and the reflection approximation is scene-specific. The built-in FPS counter is observational, not a cross-hardware benchmark. There is no networking, combat, audio, inventory or persistence layer yet.
