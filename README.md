# Soft Mountain

A playable Godot prototype about tossing soft coloured spheres into a ceramic bowl. Matching tiers merge; different tiers compress, wobble, and push each other. No fruit, imported art, paid assets, or addons.

![Soft Mountain prototype](docs/prototype.png)

## Play

Open `project.godot` in **Godot 4.6+** and press **F5**. The regular Godot build is sufficient; no C# or .NET is required. Forward+ is the default renderer. For an older GPU, launch with `--rendering-method gl_compatibility` (lighting differs).

A local standalone Windows build is available at `build/SoftMountain.exe` after exporting the **Windows Desktop** preset. Builds are excluded from source control. The prototype was developed and tested with Godot 4.6.1; the local executable is exported with the installed Godot 4.7.2 templates.

The bowl starts with three different tiers so there is something to interact with immediately. Aim at the bowl, then hold and release the left mouse button or Space to throw. Holding increases the height of the lob. The dotted arc previews the flight of the center of the ball; it does not predict collisions with the pile. Same-tier contact creates the next larger tier and awards points. The eight tiers approximately double in volume at each merge. Tier 8 stays in play and cannot merge further. A ball that escapes the bowl ends the round.

| Input | Action |
| --- | --- |
| Mouse | Aim |
| Hold/release left mouse or Space | Charge and throw |
| A / D, left / right arrows | Orbit the bowl and throwing position |
| Right-drag | Orbit with mouse |
| Wheel | Zoom |
| 1 / 2 / 3 | Balloon / foam / dough material |
| L | Toggle collision lab: no merging or game over |
| T | Toggle quarter-speed simulation |
| P / Escape | Pause/resume |
| R | Start a fresh bowl |

The on-screen buttons also expose the main controls. Material sliders apply to **all existing and new balls** immediately. Collision lab is useful for comparing sustained contact between balls of any tier. The lab allows up to 44 balls; reset to clear them.

## Soft-body implementation

This is a custom position-based solver in GDScript, rather than `SoftBody3D`. Jolt does not currently implement soft-body-to-soft-body collision response ([upstream architecture](https://github.com/jrouwe/JoltPhysics/blob/master/Docs/Architecture.md#soft-body-wip)).

Each ball has a welded icosphere cage of 42 moving particles, 120 structural edges, and 80 oriented faces. At 180 substeps per second, distance constraints resist stretching, a closed-mesh signed-volume constraint preserves bulk, and gentle rotation-independent radial recovery encourages a spherical resting shape. Internal velocity damping controls wobble without stopping the whole body's translation. Contact corrects patches of actual shell particles on both bodies, balanced by mass, so deformation changes how a pile settles. The bowl also collides with individual particles using the same analytic profile as its rendered mesh.

The rendered surface subdivides the cage into 162 vertices and 320 smooth-shaded triangles. It follows the simulated particles, with a small curved edge interpolation. It is not a scaled rigid sphere or a shader-only squash effect. Slow motion advances the same fixed steps less frequently, preserving the material settings.

**Prototype limits:** contact normals are approximated using the centers of two convex sphere-like bodies; this is not a general solver for concave meshes or cloth. There is no self-collision, tearing, liquid simulation, or plastic deformation. Extremely crowded/deeply intersecting configurations may need more resolution or a native solver. The 44-body cap bounds CPU work. The material presets are artistic approximations, not calibrated physical materials. No high-score persistence, multiplayer, or final art is included.

## Files

- `scripts/soft_ball.gd` — particle state, constraints, surface rendering.
- `scripts/soft_simulation.gd` — fixed steps, bowl and pair contacts, merging, escape detection.
- `scripts/soft_geometry.gd` — procedural cage and bowl.
- `scripts/main.gd` — input, throws, camera, lighting, effects and sound.
- `scripts/hud.gd` — interface and live tuning.
- `tests/physics_tests.gd` — deterministic simulation regressions.

All geometry and sound are generated in Godot, making the prototype easy to change without a Blender or Aseprite asset pipeline.

## Validate

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/physics_tests.gd
```

Tests cover resting shape, impact deformation and recovery, volume, mixed-tier collision, two- and three-way merges, the terminal tier, stack stability, timestep changes, escape detection, and clearing the world.

For an unattended visual smoke test:

```sh
godot --path . -- --demo --capture-frame=1800
```

This throws automatically, writes `captures/prototype.png`, then exits. `--demo` is a developer aid, not part of normal play.
