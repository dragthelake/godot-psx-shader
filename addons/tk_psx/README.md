# tk_psx

The PSX look for Godot 3D: vertex snap, affine texture mapping, per-vertex lighting, per-vertex fog, draw distance pop-in, half-resolution textures at a distance, and 15-bit colour with dither through the tk_look post chain. Depends on `tk_look` and `tk_harness`. Uses nothing renderer-specific; tested and captured in Compatibility only.

| Path | Holds |
|---|---|
| `shaders/psx.gdshaderinc` | Function library: `psx_snap_clip`, `psx_fog_factor`, `psx_beyond_draw_distance`, `psx_halve_lod`, `psx_halve_uv` |
| `shaders/psx_globals.gdshaderinc` | The `psx_*` global uniforms |
| `shaders/psx_body.gdshaderinc` | The surface shader body, configured by defines, with two hooks (`PSX_CUSTOM_VERTEX`, `PSX_CUSTOM_ALBEDO`); every variant dissolves on `tk_dissolve`, and `PSX_XRAY_MARK` and `PSX_XRAY` make the two x-ray passes |
| `shaders/psx_body_uniforms.gdshaderinc` | The body's uniforms and varyings, for hooks that read them |
| `shaders/psx_water.gdshaderinc` | Water: the body with its hooks filled in (vertex waves, two scrolling world-space texture layers) |
| `shaders/water/` | `psx_water_lit`, `psx_water_unlit`: alpha blended water |
| `shaders/variants/` | 12 thin shaders: `psx_{lit,unlit}_{opaque,scissor,blend}[_double]` |
| `shaders/xray/` | `psx_xray_mark`, `psx_xray` (meshes, on `material_overlay`) and their `_sprite` forms (chained after a PSX sprite's material): the x-ray passes |
| `shaders/psx_sprite_lit.gdshader`, `psx_sprite_unlit.gdshader` | Sprite shaders (scissor, double sided, billboard), set by `TKPsx.apply_to_sprite` |
| `psx_material_3d.gd` | `PsxMaterial3D`: typed fields that pick the variant and set its uniforms |
| `psx_water_material_3d.gd` | `PsxWaterMaterial3D`: water fields, `height()`, the seeded default texture |
| `psx_water_3d.gd` | `PsxWater3D`: a grid mesh with a `PsxWaterMaterial3D`, `height_at()` |
| `tk_psx.gd` | `TKPsx`: `reset()`, `disable()`, `set_params()`, `get_param()`, the post preset, `burst()`, `add_blob_shadow()`, `dissolve()`, `set_dissolve()`, `set_xray()` |
| `post/psx_post_quantise.tres` | The tk_look quantise pass as a `LookPass`, for a `LookPost` set up in the inspector |
| `shaders/psx_particles.gdshaderinc` | Particle shader body: camera-facing squares of whole pixels on the snap grid, PSX fog and draw distance, colour quantised to `look_colour_levels` or a palette, dither, stepped or cut fade |
| `shaders/psx_particles.gdshader`, `psx_particles_blend.gdshader` | Opaque (cut and dither fade) and alpha blended (stepped fade) particle shaders |
| `psx_particles_material_3d.gd` | `PsxParticlesMaterial3D`: `palette`, `fade`, `fade_steps`, `world_size`, `min_pixels`, `max_pixels`; `shared()` hands out one material per combination |
| `psx_particles_3d.gd` | `PsxParticles3D`: a `CPUParticles3D` with a quad, the particle material, a fixed seed and the `PixelParticles2D` presets |
| `shaders/psx_blob_shadow.gdshader` | Blob shadow disc behind `PsxBlobShadow3D`: the shared blob coverage drawn by ordered dither, with vertex snap, fog and draw distance |
| `psx_blob_shadow_3d.gd` | `PsxBlobShadow3D`: raycasts down from its parent each physics frame and lays the disc on the ground |
| `shaders/psx_sky.gdshaderinc` | Sky functions: `psx_sky_weight`, `psx_sky_gradient`, `psx_sky_band`, `psx_sky_banded` (checked against the sky fixtures), `psx_sky_azimuth`, `psx_sky_texel` |
| `shaders/psx_sky.gdshader` | Sky shader behind `PsxSkyMaterial`: gradient or panorama, sun disc, cloud band, banding |
| `psx_sky_material.gd` | `PsxSkyMaterial`: typed sky fields, `gradient_at()`, the seeded default cloud band |
| `lab/psx_lab.tscn` | The PSX look lab |
| `lab/water_lab.tscn` | The PSX water lab: a stone pool with pillars, stepping stones and crates |
| `lab/particles_lab.tscn` | The PSX particles lab: every preset near and far, frozen so every run draws the same picture |
| `lab/shadow_lab.tscn` | The PSX shadow lab: capsules on flat ground, a step and a slope, one hovering, and a sprite in the fog |
| `lab/sky_lab.tscn` | The PSX sky lab: floor and pillars running into fog under a gradient sky with sun and clouds, or a panorama sky (M switches) |
| `lab/sprite_fx_lab.tscn` | The PSX sprite effects lab: crates and sprite figures dissolved by 0, 25, 50 and 75 percent, and three figures at a brick wall with the x-ray on. Frozen at a fixed time; the `Clock` child's `time_override` (or `--time=<seconds>`) picks it, negative animates |

## Turning it on in a base

1. Run `scripts/link-addons` so `addons/tk_psx` is linked, and keep the `TKLook` autoload (it registers the `psx_*` globals a project does not declare).
2. Give meshes a `PsxMaterial3D` (`material_override` or surface material) and set shading, transparency, double sided, texture and colour in the inspector. In code: `PsxMaterial3D.make(texture, colour)`. `world_uv` takes UVs from world position (box projection, one repeat per metre times `uv_scale`) for geometry without authored UVs, like StandardMaterial3D's world triplanar.
3. Put a `LookPost` inside the `SubViewport` that renders the game at internal resolution and give it the PSX chain: `TKPsx.apply_post(post)`, or add `post/psx_post_quantise.tres` to its passes.
4. Keep the snap grid at the internal resolution (default 320x240), e.g. `TKPsx.set_params({"psx_snap_resolution": Vector2(320, 240)})`. Fog, draw distance and texture LOD defaults come from `assets/source/look/look.json`.

Existing scenes built with StandardMaterial3D, such as the greybox, convert in one call: `TKPsx.convert_materials(root)` swaps each `material_override` and surface override for `PsxMaterial3D.from_standard(material)` (albedo, UV scale and offset, world triplanar as `world_uv`, unshaded, transparency, cull) and tessellates box, prism and plane meshes to 2 m edges. Tessellation matters: fog, texture LOD and draw distance are per vertex, so a 40 m floor face fogs and culls as a whole. `TKPsx.tessellate(mesh, max_edge)` does the same for one mesh.

Sprites take the same effects through `TKPsx.apply_to_sprite(sprite)`, for `Sprite3D`, `AnimatedSprite3D` and `TKSprite3D`: the PSX sprite shader (`shaders/psx_sprite_lit.gdshader` or `psx_sprite_unlit.gdshader`, from the sprite's `shaded`) goes on `material_override`, with the sprite's billboard mode done in the vertex shader before the snap, alpha cut at 0.5 and modulate kept. The shader follows the sprite's texture or animation frame through its signals. Call it again after changing `billboard` or `shaded`. `convert_materials` applies it to every sprite under the root. `Label3D` is not covered: its glyphs draw from per-surface font textures that an override material cannot see, so keep labels in the UI or render text into a sprite texture.

Fog is a material effect, not an `Environment` one: give the environment a PSX sky (below), whose horizon is `psx_fog_colour`, or set the background colour to `psx_fog_colour`, so the horizon matches.

## Parameters

| Global | Effect | Off |
|---|---|---|
| `psx_snap_resolution` | Vertices snap to whole pixels of this grid | `Vector2.ZERO` |
| `psx_affine` | Affine texture mapping | `false` |
| `psx_fog_colour`, `psx_fog_start`, `psx_fog_end` | Per-vertex fog from start to end metres | end not above start |
| `psx_draw_distance` | Triangles with a vertex beyond this are not drawn | `0` |
| `psx_texture_lod_distance` | Textures sample at half resolution beyond this | `0` |
| `look_colour_levels` (tk_look) | Quantise levels per channel; 32 is 15-bit colour | post chain inactive |

Set them through `TKPsx` or `TKLook.set_param`, so `get_param` can report them: Godot cannot read a global shader parameter back outside the editor.

## Lab

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 2d -Scene res://addons/tk_psx/lab/psx_lab.tscn -Frames 60 -Name psx/lab-on
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 2d -Scene res://addons/tk_psx/lab/psx_lab.tscn -Frames 60 -Name psx/lab-off -GameArgs '--look=off'
```

`--look=off` turns every effect and the post chain off. `--snap=80x60` coarsens the snap grid so the snapping is visible in a still. The lab sets fog to end past the draw distance so pop-in is visible; a game usually hides it inside solid fog.

## Water

`PsxWater3D` is a `MeshInstance3D`: a flat grid of `size` metres with a vertex every `cell_size` metres, centred on the node, drawn with a `PsxWaterMaterial3D`. The material is the PSX surface body with its hooks filled in, so vertex snap, affine mapping, per-vertex fog and lighting, draw distance and texture LOD all apply:

- Waves: two sines in world space (`wave_height`, `wave_length`, `wave_speed`, `wave_direction`) lift the vertices before they are snapped. Normals follow the slope, so the vertex lighting rolls with the waves; crests brighten by `crest_brightness`.
- Texture: `albedo_texture` mapped in world space, one repeat per `texture_size` metres, in two layers scrolling by `scroll_a` and `scroll_b` (the second scaled by `layer_b_scale` and turned), averaged. With no texture set it uses a 32x32 texture generated from a seeded PCG32 stream.
- Alpha blended at `albedo_colour.a`. `shading` picks lit or unlit.
- `time_override` of 0 or more freezes the water, for captures and tests. `PsxWater3D.height_at(position)` gives the surface height the shader draws, for floating things.

Waves only bend the surface at vertices, so keep `cell_size` under a third of `wave_length`.

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/water_lab.tscn -Name water/psx-lab -Frames 30
```

The water lab takes `--time=<seconds>` (negative animates) and `--look=off`.

## Particles

`PsxParticles3D` is the PSX side of styled particles, with the same presets, fades and seeds as `PixelParticles2D` in `tk_pixel`.

```gdscript
TKPsx.burst(self, PsxParticles3D.Preset.SPARKS, hit_point)   # plays once, frees itself
```

- Each particle is a camera-facing square of whole pixels laid on the `psx_snap_resolution` grid (the viewport's pixels when snapping is off), so it moves a pixel at a time like snapped vertices. Size is `world_size` metres times the particle's scale (`scale_amount` and its curve), projected and rounded, between `min_pixels` (default 1, so far particles do not vanish) and `max_pixels`.
- Fog and draw distance follow the `psx_*` globals like the surface shaders. Colour is mixed with the fog in sRGB, then quantised to `look_colour_levels` or, with `palette_name` set, the nearest palette colour.
- Fade: `DITHER` (default) and `CUT` use the opaque shader, depth tested like any opaque surface; `STEPS` uses the blended one.
- Deterministic, `freeze_at(t)`, `burst(..., seed)` and the `TKPool` hooks work as in `PixelParticles2D`.

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/particles_lab.tscn -Name particles/psx-lab -Frames 30
```

## Shadows

`PsxBlobShadow3D` is the PSX and N64 blob shadow: a dark disc on whatever is under its parent.

```gdscript
TKPsx.add_blob_shadow(body, 0.9, 0.8)   # disc 0.9 m across; body origin 0.8 m above its feet
```

- Each physics frame it casts a ray (`PhysicsDirectSpaceState3D.intersect_ray`) straight down through its parent's origin, from `ray_start` above it to `max_distance` below, on `collision_mask`. The nearest `CollisionObject3D` at or above the parent is excluded, so the body never shadows itself onto its own collider. `update_shadow()` runs the same step at once, after moving the parent outside physics.
- The disc is a top-level quad laid `lift` metres above the hit point and turned to the surface normal, so it lies on steps and slopes. Nothing within `max_distance`, and it hides.
- `height` is the parent's height above the hit past `foot_offset` (0 for an origin at the feet, half the height for a centred capsule). The disc scales to `height_scale` of `size` and its opacity to `height_opacity` at `height_range` metres.
- Drawn with `shaders/psx_blob_shadow.gdshader`: one colour (sRGB `colour`) where `tk_blob_coverage` and `tk_shadow_dither` (`tk_look/shaders/look_shadow.gdshaderinc`, the pixel stack's blob maths) say so, on internal-resolution pixels counted from the top-left, clear elsewhere. Vertex snap, per-vertex fog and the draw distance cull follow the `psx_*` globals. It draws in the transparent pass without writing depth; `depth_pull` (default 1%) draws it that share of its distance nearer the camera, which leaves it where it is on screen but keeps it above the ground's depth where vertex snap moves the two apart.

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/shadow_lab.tscn -Name effects/psx-shadow -Frames 60
```

The shadow lab takes `--time=<seconds>` (the hover, negative animates) and `--look=off`.

## Sky

`PsxSkyMaterial` is a sky material (`shader_type sky`) for the environment's `Sky`. It draws a vertical gradient from `zenith_colour` through the horizon to the ground, quantised per channel and dithered in screen space with the tk_look quantise maths, so the sky looks the same with the post chain off.

```gdscript
var env := TKPsx.make_sky(PsxSkyMaterial.make(Color("#1b3a6b")))  # a new Environment
var sky := TKPsx.apply_sky($World/Environment)                      # onto a WorldEnvironment
```

`make_sky` lights the scene with a flat ambient colour and no reflections, so the sky is never rendered into a radiance map. `apply_sky` changes only the background of an existing environment.

- Horizon: `horizon_follows_fog` (on) makes the horizon colour the `psx_fog_colour` global, read in the shader, so geometry at full fog meets the sky with no seam, whatever the fog colour is set to at runtime. `ground_follows_fog` (on) does the same below the horizon, which hides the gap where the ground ends or passes the draw distance short of the horizon. `horizon_height` moves the horizon line and `sharpness` (1 linear, higher thinner) sets how fast the colour leaves the horizon. Elevations are the sine of the angle above level.
- Banding: each channel quantised to `band_levels` (0 follows `look_colour_levels`, 32 is 15-bit colour) with the `look_bayer_size` matrix at `look_dither_strength` when `dither` is on. The colour is snapped to 8 bits before and after, so the sky is exactly what the quantise pass would draw over a smooth sky. Under the post chain both run: a pixel already on a level can move one level on the extreme Bayer cells, which stays inside the dither pattern.
- Sun: `sun_enabled`, `sun_direction` (or `sun_follows_light` for the first `DirectionalLight3D`), `sun_size` (angular radius in degrees), `sun_colour`, and a `sun_halo` ring as wide as the disc.
- Clouds: `clouds_enabled` draws `cloud_texture` (default: a seeded 64x8 band) between `cloud_low` and `cloud_high`, wrapped `cloud_repeats` times around the horizon, texels with alpha 0.5 and up as cloud. It scrolls `cloud_speed` texels a second a whole texel at a time.
- Panorama: `mode = PANORAMA` draws `panorama` above the horizon, bottom row at the horizon and top row at the zenith, sampled nearest on a `panorama_resolution` grid (0 is the texture's size). It fades in from the horizon colour over `panorama_fade`. Below the horizon `panorama_below` picks the ground gradient or the panorama mirrored. Keep panoramas small; the lab's is 256x64.
- `time_override` of 0 or more freezes the clouds, for captures and tests. `gradient_at(elevation)` gives the gradient colour before banding, for anything that must match the sky.

Written for the Compatibility renderer, which takes the sky colour as sRGB; Forward+ and Mobile expect linear and are not covered.

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/sky_lab.tscn -Frames 60 -Name effects/sky-gradient
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/sky_lab.tscn -Frames 60 -Name effects/sky-panorama -GameArgs '--sky=panorama'
```

The sky lab takes `--time=<seconds>` (negative pans the camera and scrolls the clouds), `--sky=gradient|panorama` and `--look=off`, and has a `time_override` property for the gallery.

## Dissolve

Every PSX surface and sprite shader dissolves on the `tk_dissolve` instance uniform, in whole texels of `albedo_texture` (after affine mapping, so the pattern warps and sticks with the texture). Gone texels are cut by the alpha scissor in scissor variants and sprites, and discarded in the others.

```gdscript
await TKPsx.dissolve(enemy, 0.6).finished   # away; every mesh and sprite under enemy
TKPsx.dissolve(pickup, 0.4, false)          # back in
TKPsx.set_dissolve(crate, 0.5)              # held
```

`PsxMaterial3D` picks the pattern (`dissolve_cell`: 0 ordered, 1 hashed, 2 or more blobs about that many texels across), the edge (`dissolve_edge_width` texels of `dissolve_edge_colour`, unlit, round the holes; 0 turns it off) and the texel grid (`dissolve_texels` per UV unit; zero uses the texture's size, so set it on untextured surfaces). Sprites from `apply_to_sprite` use the shader defaults. The pattern is `tk_look/shaders/look_dissolve.gdshaderinc`.

## X-ray

`TKPsx.set_xray(node, on, colour, dither)` gives every mesh and PSX sprite at or under `node` a flat silhouette where something opaque hides it. Two passes, in the transparent queue after everything else:

1. Mark (`psx_xray_mark`, render priority 120): draws where the actor itself is visible, writing stencil value 64. It also draws `tk_flash`, so `TKLook.flash` still works on an actor with the x-ray on.
2. Silhouette (`psx_xray`, render priority 121): `depth_test_inverted`, so it draws only behind what is already in the depth buffer, and stencil `compare_not_equal` 64, so the actor's own visible parts never show a silhouette of its hidden parts. It writes 64 too, so overlapping parts draw once.

Both passes run the PSX vertex snap and draw 5 cm nearer the camera than the surface, so the actor's visible surface never counts as behind itself. Meshes take the passes as `material_overlay` (shared, with `tk_xray_colour` and `tk_xray_dither` as instance uniforms); PSX sprites take them as the next pass of their own material, billboarded and cut out like the sprite. `dither` (0 to 1) leaves out that share of the silhouette by a 4x4 Bayer pattern on the screen. Works on the Compatibility renderer; `test/test_psx_fx_render.gd` checks it there.

Instance uniforms on one mesh share slots across its material and overlays, so the PSX and tk_look 3D shaders give each a fixed `instance_index` (see the tk_look README).

```
xvfb-run -a -s "-screen 0 1920x1080x24" scripts/capture godot 3d -Scene res://addons/tk_psx/lab/sprite_fx_lab.tscn -Name effects/psx-sprite-fx -Frames 60
```

## Tests

`test/test_psx_material.gd`, `test/test_psx_lab.gd`, `test/test_psx_water.gd`, `test/test_psx_particles.gd`, `test/test_psx_blob_shadow.gd` (ray, own body ignored, step, slope, height, hiding, the lab), `test/test_psx_sky.gd` and `test/test_psx_fx.gd` (dissolve and x-ray helpers, the sprite effects lab) run headless. `test/test_psx_sprite.gd` checks `apply_to_sprite` headless and renders sprite texture, frame, billboard and fog under `-Render`. `test/test_psx_render.gd` renders vertex snap, fog, draw distance and affine mapping, `test/test_psx_water_render.gd` renders the water (same image at the same time, time and waves change it, the floor shows through, fog and vertex snap reach it), `test/test_psx_particles_render.gd` renders particles (square size, one-pixel minimum, quantised and palette colour, fog, draw distance, same seed same picture), `test/test_psx_blob_shadow_render.gd` renders the blob shadow (the shared dither pattern from the top-left at Bayer 2, 4 and 8, shadow colour only, height, fog and draw distance), `test/test_psx_sky_render.gd` renders the sky fixtures from `assets/source/look/fixtures/sky_*.json` at tolerance 0 through `test/psx_sky_fixture.gdshader`, then the sky shader (bands on the colour grid, identical to the quantise pass over a smooth sky, the horizon meeting a fogged floor, the fog colour global, frozen and scrolling clouds, whole panorama texels, the mirror), and `test/test_psx_fx_render.gd` renders the dissolve of a 32 x 32 texture against the `dissolve_hash` fixture texel for texel, the x-ray behind a wall (only where hidden, not over the actor's own parts, dithered, on a sprite) and the hit flash on a dissolving surface and through the x-ray overlay; all run under `scripts/test godot -Render`. The tk_look compile check covers every shader here.
