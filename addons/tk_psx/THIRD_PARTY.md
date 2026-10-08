# Third-party code in tk_psx

| What | Where it went | Source | Licence |
|---|---|---|---|
| Vertex snap in clip space, affine texture mapping (UV times w in the vertex stage, divided in the fragment stage), per-vertex fog factor, draw distance cull by a NaN position, half-resolution texture LOD beyond a distance, the sRGB to linear conversion, and the render modes of the vertex-lit variants (`vertex_lighting`, `diffuse_lambert_wrap`, `specular_disabled`, `shadows_disabled`) | `shaders/psx.gdshaderinc`, `shaders/psx_body.gdshaderinc` | [Ultimate Retro Shader Collection](https://github.com/Zorochase/ultimate-retro-shader-collection), `shaders/ursc/spatial/common.gdshaderinc` and `utilities.gdshaderinc` | MIT |
| Scrolling UV: UV plus a scroll speed times time, used for both water texture layers | `shaders/psx_water.gdshaderinc` | [Ultimate Retro Shader Collection](https://github.com/Zorochase/ultimate-retro-shader-collection), `uv_scroll_speed` in `shaders/ursc/spatial/common.gdshaderinc` | MIT |
| The pattern of a `ShaderMaterial` subclass with typed inspector fields that picks a shader variant and forwards uniforms. No code copied. | `psx_material_3d.gd` | [psx_visuals](https://github.com/snotbane/psx_visuals), `addons/psx/scripts/PsxMaterial3D.gd` | Unlicense |

The particle shaders (`shaders/psx_particles.gdshaderinc` and its two variants) are written for the toolkit and call the ported `psx_fog_factor`, `psx_beyond_draw_distance`, `psx_culled_position` and `psx_srgb_to_linear`. `PsxParticlesMaterial3D` follows the same variant-picking pattern as `PsxMaterial3D`. No other code is ported for particles.

The blob shadow (`shaders/psx_blob_shadow.gdshader`, `PsxBlobShadow3D`) is written for the toolkit and calls the ported `psx_snap_clip`, `psx_fog_factor`, `psx_beyond_draw_distance`, `psx_culled_position` and `psx_srgb_to_linear`. No MIT or CC0 Godot blob shadow was found to port: the search turned up decal tutorials (Godot's `Decal` node is not in the Compatibility renderer) and shadow add-ons for 2D only.

The sky (`shaders/psx_sky.gdshaderinc`, `shaders/psx_sky.gdshader`, `PsxSkyMaterial`) is written for the toolkit and calls tk_look's `tk_snap8` and `tk_dither_quantise`. URSC's `flat_sky.gdshader` is a scrolling texture on a mesh, not a sky shader, and the MIT sky shaders on godotshaders.com are smooth or ray-marched; none was ported.
The x-ray passes (`PSX_XRAY_MARK` and `PSX_XRAY` in `shaders/psx_body.gdshaderinc`, `shaders/xray/`) follow the technique of [stencil based silhouette](https://godotshaders.com/shader/stencil-based-silhouette/) on godotshaders.com (CC0): the actor writes a stencil value, and a next pass with `depth_test_inverted` and `stencil_mode read, write, compare_not_equal` draws the silhouette. No code is copied. The toolkit writes the stencil from its own mark pass on `material_overlay` instead of the actor's material, so surface materials stay shared, and draws both passes nearer the camera by a bias. The dissolve in the body is written for the toolkit.

Changes from Ultimate Retro Shader Collection:

- Global uniforms renamed to the toolkit's `psx_*` parameters from `assets/source/look/look.json`.
- Vertex snap rounds to whole pixels of `psx_snap_resolution` (URSC floors to half-pixel steps of a fixed 320x240 grid times an intensity).
- Fog and draw distance measure the view-space distance of the vertex (URSC includes the w component of the view-space position in the length).
- Texture LOD samples the centre of the top-left texel of each 2x2 block, so the result does not depend on how the sampler rounds at a texel edge.
- Fog, draw distance and texture LOD have no per-material overrides; texture filtering, billboard, shiny and metal modes are not ported. UV scroll is used only by the water, on world-space UVs.

The rest of the water (vertex waves, slope normals, crest brightening, the two-layer mix, the body hooks) is written for the toolkit. URSC has no water shader.

## MIT licence of Ultimate Retro Shader Collection

```
MIT License

Copyright (c) 2024-2026 Zorochase

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
