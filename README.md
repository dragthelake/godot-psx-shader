# PSX Shader for Godot 4

The PlayStation 1 look for Godot 4.7 3D: vertex snap (wobbly vertices), affine texture warp, per-vertex lighting and fog, draw distance pop-in, half-resolution textures at a distance, and 15-bit colour with ordered dither. Also PSX water, particles, sky, blob shadows, dissolve and x-ray.

Built for the **Compatibility** renderer (Project Settings > Rendering > Renderer). Forward+ and Mobile are not tested.

## Try it

Open this folder in Godot 4.7 and press Play. Keys 1 to 6 switch demos, and everything runs live.

| Key | Demo |
|---|---|
| 1 | PSX look: vertex snap, affine floor, fog, pop-in, dither, vertex lights |
| 2 | Water |
| 3 | Particles (one-shot effects replay every 1.5 s) |
| 4 | Sky (M swaps gradient and panorama) |
| 5 | Dissolve and x-ray |
| 6 | An ordinary scene with StandardMaterial3D and 512 px textures, made PSX by `PsxScreen` |

L steps up the look ladder and Shift+L back down. It starts on Full PSX.

| Step | Resolution | Textures | PSX surfaces | 15-bit colour |
|---|---|---|---|---|
| Modern | window, filling it | as made | off | off |
| Hi-res PSX | window, filling it | as made | on | on |
| Hi-res PSX, crunchy textures | window, filling it | 256 px | on | on |
| Mid PSX | 640x480 | 256 px | on | on |
| Full PSX | 320x240 | 256 px | on | on |

Vertex snap stays on its 320x240 grid at every resolution, so the hi-res steps still wobble. In demo 6, Modern puts the scene's original StandardMaterial3D materials back; the labs are built from PSX materials, so there Modern turns their effects off instead. The ladder is `demo/demo.gd`.

## Put it in your own project

1. Copy `addons/` (all three folders: `tk_psx`, `tk_look`, `tk_harness`) into your project.
2. Add the autoload: Project Settings > Globals > Autoload, path `res://addons/tk_look/tk_look.gd`, name `TKLook`. It registers the shader globals the PSX shaders read.
3. Copy the `[shader_globals]` section of this `project.godot` into yours. Optional (TKLook registers them at runtime), but the editor only previews the shaders with them declared.
4. Set the renderer to Compatibility.

Then either:

**Quick way.** Copy `demo/psx_screen.gd` too. Make a scene whose root is a `Control` with that script, set its `scene` to your 3D scene, and run it. It renders your scene at 320x240, converts every `StandardMaterial3D` and `Sprite3D` to PSX, adds the colour quantise pass, and scales up with hard pixels. `demo/quickstart.tscn` is exactly this.

**By hand.**
- Give meshes a `PsxMaterial3D` (inspector: shading, transparency, texture, colour; `world_uv` for geometry with no UVs). Or call `TKPsx.convert_materials(root)` to convert a whole scene; it also cuts big boxes and planes into 2 m pieces, which fog and pop-in need because they work per vertex.
- `TKPsx.apply_to_sprite(sprite)` for `Sprite3D` and `AnimatedSprite3D`.
- Render the 3D scene in a `SubViewport` at a low resolution (320x240 is the classic) and put a `LookPost` node inside it with `TKPsx.apply_post(post)` for the 15-bit colour and dither.
- Match the snap grid to that resolution: `TKPsx.set_params({"psx_snap_resolution": Vector2(320, 240)})`.
- Set the environment background to the fog colour, or use `TKPsx.make_sky()`, so the horizon meets the fog.

## Tuning

```gdscript
TKPsx.set_params({
	"psx_fog_colour": Color("#3a4466"),
	"psx_fog_start": 6.0,
	"psx_fog_end": 30.0,
	"psx_draw_distance": 40.0,     # 0 turns pop-in off
	"psx_affine": true,            # texture warp
	"psx_texture_lod_distance": 12.0,
})
TKLook.set_param("look_colour_levels", 32.0)   # per channel; 32 is 15-bit colour
TKPsx.disable()   # everything off
TKPsx.reset()     # back to the defaults
```

`addons/tk_psx/README.md` covers everything in detail: water (`PsxWater3D`), particles (`TKPsx.burst`), blob shadows (`TKPsx.add_blob_shadow`), the sky (`PsxSkyMaterial`), dissolve (`TKPsx.dissolve`) and x-ray (`TKPsx.set_xray`). It mentions toolkit scripts and tests that are not in this package; ignore those parts.

## Licence

MIT, see `LICENSE`. Third-party parts keep their own licences, listed below.

## Credits

Parts of the vertex snap, affine mapping, fog and draw distance come from [Ultimate Retro Shader Collection](https://github.com/Zorochase/ultimate-retro-shader-collection) (MIT). Screen transitions in `tk_look` are from Universal Transition Shader (CC0). See `addons/tk_psx/THIRD_PARTY.md` and `addons/tk_look/THIRD_PARTY.md`.
