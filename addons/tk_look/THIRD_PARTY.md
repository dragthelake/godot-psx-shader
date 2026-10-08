# Third-party code in tk_look

| File | Source | Licence | Changes |
|---|---|---|---|
| `shaders/transition.gdshader` | [Universal Transition Shader](https://github.com/cashew-olddew/Universal-Transition-Shader) by cashew-olddew | CC0 1.0 | Added Dissolve and Wipe types, `aspect` (round shapes on wide screens) and `pixel_grid` (snap to game pixels). Marked `game-toolkit` in the source. |

`tk_hash01` in `shaders/look_particles.gdshaderinc` is the integer hash `n * (n * n * 15731 + 789221) + 1376312589` widely published in Hugo Elias's noise article and many shader libraries: one formula, not ported code. The rest of that file is written for the toolkit.

`tk_hash_u32` in `shaders/look_dissolve.gdshaderinc` is lowbias32 from Chris Wellons's [hash-prospector](https://github.com/skeeto/hash-prospector) (public domain, Unlicense): two constants and three shifts, not ported code. The dissolve pattern built on it is written for the toolkit. The dissolve shaders on godotshaders.com that were checked are GPL v3 ("Pixelated Dissolve with Block Size") or have no texel space edge, so none was ported.

The palettes in `generated/palettes` are listed in `assets/source/look/palettes/README.md`.
