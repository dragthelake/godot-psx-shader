# tk_look

Look family, shared by the PSX and Pixel stacks. Spec: `docs/specs/2026-10-03-shaders-design.md`.

## Turning it on

1. Autoload `TKLook="*res://addons/tk_look/tk_look.gd"` in `project.godot`.
2. Run `scripts/export look`, which writes the look parameters into the project's `[shader_globals]` (any project with the `TKLook` autoload). `TKLook` registers missing ones at startup anyway, but the editor only previews shaders whose globals are declared.
3. Set `toolkit/look/internal_resolution` (for example `Vector2i(320, 180)`) so transitions snap to game pixels.
4. Add a `LookPost` node inside the SubViewport that renders the game at internal resolution and give it passes.

## Files

| Path | What it is |
|---|---|
| `shaders/look.gdshaderinc` | Function library: `tk_snap8`, `tk_bayer_threshold`, `tk_quantise`, `tk_dither_quantise`, `tk_palette_nearest`, `tk_palette_dither`, `tk_screen_pixel`. Pure functions, no uniforms. |
| `shaders/look_particles.gdshaderinc` | Styled particle functions shared by the pixel and PSX particle shaders: `tk_hash01`, `tk_particle_pixels`, `tk_particle_origin`, `tk_fade_alpha`. Includes `look.gdshaderinc`. |
| `shaders/look_shadow.gdshaderinc` | Drop shadow functions shared by `PixelShadow2D` and `PsxBlobShadow3D`: `tk_blob_coverage` (ellipse with a linear edge) and `tk_shadow_dither` (drawn or not by ordered dither). Includes `look.gdshaderinc`. Checked against the `shadow_blob_*` fixtures. |
| `shaders/look_dissolve.gdshaderinc` | Dissolve pattern shared by the pixel sprite shader and the PSX surface body: `tk_hash_u32`, `tk_hash8`, `tk_dissolve_level`, `tk_dissolve_threshold`, `tk_dissolve_state`. Integer maths, per texel. Includes `look.gdshaderinc`. |
| `shaders/look_globals.gdshaderinc` | `look_colour_levels`, `look_dither_strength`, `look_bayer_size` and the `look_crt_*` parameters. |
| `shaders/post_quantise.gdshader` | Post pass: quantise per channel with ordered dither. 32 levels is 15-bit colour. |
| `shaders/flash_canvas.gdshader`, `flash_3d.gdshader` | Hit flash on the `tk_flash` and `tk_flash_colour` instance uniforms. The 3D one goes on `material_overlay`, with fixed instance indices (see Instance uniforms). |
| `shaders/outline_3d.gdshader` | Inverted hull outline with a width in internal-resolution pixels, for `material_overlay`. |
| `shaders/crt.gdshaderinc`, `crt.gdshader` | CRT display pass: barrel curvature, one scanline per internal row with a beam that widens on bright rows, aperture grille, vignette. |
| `shaders/transition.gdshader` | Screen transitions, ported from Universal Transition Shader (CC0). |
| `post/look_post.gd`, `post/look_pass.gd` | `LookPost` (a `CanvasLayer` at layer 100) and `LookPass` (an enabled flag and a `ShaderMaterial`). Each enabled pass is a `BackBufferCopy` and a full-screen `ColorRect`, so passes chain. |
| `tk_look.gd` | The `TKLook` autoload. |
| `generated/` | Output of `scripts/export look`: Bayer matrices, `TKLookDefaults` (look.json defaults) and palette strips. Do not edit. |
| `lab/transition_lab.tscn` | A test card with a transition held at a fixed amount: `--transition=<kind>@<amount>`. |
| `gallery/tk_look_gallery.gd` | `TKLookGallery`, the shader gallery that `PixelGallery` and `PsxGallery` extend. |
| `gallery/tk_look_file.gd` | `TKLookFile`: writes parameter defaults into `look.json` without changing its layout, and runs `scripts/export look`. |

## Parameters

Stack-wide values are global shader parameters named `look_*`, `psx_*` and `pixel_*`, with defaults in `assets/source/look/look.json`. Set them with `TKLook.set_param(name, value)`, read them with `TKLook.get_param`, and restore defaults with `TKLook.reset_params(prefix)`. `RenderingServer` cannot read global parameters outside the editor, so `TKLook` tracks the values it sets.

## CRT

`TKLook.set_crt(display, on)` puts the CRT display pass on the node that draws the internal-resolution image to the screen: the 2D base's `PixelView` (a `SubViewportContainer`) or the 3D base's `Screen` (a `TextureRect`). It is not a `LookPost` pass: post runs at internal resolution, and a scanline gap or an aperture grille is smaller than one game pixel, so this pass runs at screen resolution while keeping one scanline per internal row. UI drawn above the display stays flat. Parameters: `look_crt_curvature`, `look_crt_scanline`, `look_crt_mask`, `look_crt_bloom`, `look_crt_vignette`. With all five at 0 the pass is a nearest upscale. Scanlines need at least 3 screen pixels per internal row (720p and up).

## Shader gallery

`scenes/shader_gallery.tscn` in each base (F2 lists it) shows the stack's labs one page at a time, running live: `PixelGallery` in base-2d (pixel look, particles, water, shadows, rotation, sprite effects) and `PsxGallery` in base-3d (PSX look, particles, water, shadows, sky, sprite effects). `]` or Page Down turns to the next page, `[` or Page Up to the previous one.

Tab or F6 opens the panel (on a Mac keyboard F6 needs fn):
- **Pages and effects:** a page list, Replay effects (one-shot particles also replay every 1.5 s), and a transition list with Play transition.
- **Look on, CRT, Preset and Palette:** Look on also turns the PSX surface effects off. Preset (base-2d) takes a look preset's palette, dither spread and Bayer size (see `tk_pixel/README.md`); Palette is the pixel stack's post palette on its own. Save writes the parameters, not the palette.
- **Parameters:** one control for each of the stack's look parameters, starting from `look.json`. The gallery's values replace any a lab sets for itself.
- **Save to look.json:** writes those values as the new defaults (`TKLookFile.save`) and runs `scripts/export look`, which regenerates the Godot defaults, every project's `[shader_globals]` and the Unreal files. Commit the result. Only the changed defaults move in `look.json`. Save needs the project to run from the checkout.
- **Revert:** goes back to the last saved values.

Arguments after `--`: `--page=<number or title>`, `--preset=<name>`, `--look=off`, `--crt=on`, `--panel=on` (opens the panel, for captures).

A game or demo can offer the same panel over its own scene: `attach_to(scene)` before adding the gallery makes it tune that scene, with no pages, caption or page keys, and the scene keeps its own animation. `status_changed` reports the result of a save, for scenes that show it. `godot/pixel-showcase` and `godot/psx-showcase` use it.

```gdscript
var gallery := PixelGallery.new()
gallery.attach_to(self)
add_child(gallery)
gallery.use_preset("game-boy")
```

## Transitions

`await TKLook.transition_out(kind, duration)` covers the screen, `transition_in` uncovers it, `change_scene(path, kind)` does both around a scene change, and `set_transition(kind, amount)` holds one still. Kinds: `fade`, `box`, `blinds`, `diamond`, `circle`, `clock`, `dissolve`, `wipe`. Transitions draw at layer 128 of the root viewport, over the UI.

## Dissolve

`look_dissolve.gdshaderinc` gives every texel of a sprite or surface texture a threshold in (0, 1); at dissolve amount `a` the texels below `a` are gone, and kept texels with a gone texel within the edge width (`|dx| + |dy| <= edge`) draw in an edge colour. `tk_dissolve_level(texel, cell)` picks the pattern:

- `cell` 0: ordered, the 8x8 Bayer matrix (level `4 * bayer + 2`).
- `cell` 1: hashed, `lowbias32(x + lowbias32(y)) >> 24` per texel.
- `cell` 2 or more: value noise with lattice points every `cell` texels (bilinear at texel centres, in integers), mixed 7:1 with the texel hash, then stretched by 2 about 128 and clamped to 0..255.

The threshold is `(level + 0.5) / 256`. Everything up to it is integer maths, so the level is exact in every engine; `assets/source/look/fixtures/look_fixtures.py` holds the reference and writes the `dissolve_*` fixtures. `TKPixel.dissolve` and `TKPsx.dissolve` drive it.

## Instance uniforms

A 3D node's instance uniforms share one set of slots across its material, `material_overlay` and their next passes, so two names with the same slot overwrite each other (on the Compatibility renderer the overlay then does not draw). The 3D shaders in the toolkit give each name a fixed `instance_index`: `tk_flash` 0, `tk_flash_colour` 1, `tk_dissolve` 2, `tk_xray_colour` 3, `tk_xray_dither` 4. A new 3D instance uniform takes the next free index. Canvas items have one material each, so 2D shaders do not need this.

## Tests

- `test/test_compile_shaders.gd` compiles every `.gdshader` in `tk_look`, `tk_pixel` and `tk_psx` headless and fails on any compile error.
- `test/test_look_render.gd` renders the quantise fixtures from `assets/source/look/fixtures` and compares every pixel at tolerance 0. It skips itself under `--headless`; `scripts/test -Render` runs it (in the cloud container, under `xvfb-run`).
- `test/test_look_file.gd` checks that `TKLookFile` changes only the named defaults and finds the checkout's `look.json`. `tk_pixel` and `tk_psx` test their galleries.
- `test/test_crt.gd` checks `set_crt`, and renders the CRT pass at 3x: all effects off is an exact nearest upscale, scanlines darken between rows, the mask splits white into columns, and curvature blacks out the corners.
- `test/test_dissolve_render.gd` renders `tk_dissolve_level` and `tk_dissolve_state` for every case of the four `dissolve_*` fixtures and compares them at tolerance 0.
- `test/look_fixture_runner.gd` (`LookFixtureRunner`) renders any fixture through any passes, for the other families' tests.
