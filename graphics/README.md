# Graphics source

## Rounded machines

The current provider and requester art is in `entities/rounded-v1/`. Both models
were authored directly through Blender MCP from
`concepts/rounded-transfer-v1.png` and rendered in Blender 5.2.3 LTS.

Editable source: `source/rounded-transfer-v1/rounded-transfer-v1.blend`.
The `ILN - Provider` and `ILN - Requester` scenes hold the named meshes and
procedural materials. `ILN - Presentation` uses collection instances to display
the pair. The concept is packed into the file; there are no external textures.
The materials include mottled enamel, machined steel, copper and emissive coolant.
Vent cassettes, fasteners, power buses, hazard markings and role stencils are
editable geometry. Existing scenes were preserved during authoring.

Frames 1–64 are idle; 65–128 are active. Drivers animate the scanning iris and
transport rings without external handlers. TX rings move upward; RX rings move
downward. The separate body and precolored additive emission sheets have the
same 192×256 cells, 8×8 grid, `.625` scale and vertical shift as the prior assets.
The orthographic camera uses 51.2 pixels per tile and a fixed native anchor of
`(96, 156.9630937574)`. Shadows are 384×256, projected from the evaluated model
geometry and softened during packing. The world footprint remains 3×3 tiles.

To reproduce the models in an empty Blender file, execute `build_models.py`,
then `refine_models.py` from the source directory. Execute `export_sprites.py`,
then render animation for the Provider and Requester scenes. Execute
`export_shadows.py`, then render each Shadow scene. Finally run:

```sh
uv run --with pillow python graphics/source/rounded-transfer-v1/pack_sprites.py
```

Blender supplies every rendered pixel. Pillow downsamples the 2× renders,
packs the sheets and makes review previews. `manifest.json` records dimensions,
frame counts, clipping checks and SHA-256 hashes. The preview GIF is slowed for
inspection; `native-sprite-preview.png` shows the actual sprite size. These are
Blender previews, not screenshots from Factorio.

Source files and concept art are excluded from mod release archives.

The current `thumbnail.png` was made with the built-in imagegen tool using the
actual rounded-model render and the previous thumbnail as references, then
resized to 512×512. The full image and final prompt are preserved as
`source/rounded-transfer-v1/mod-icon-full.png` and `mod-icon-prompt.txt`.

## Previous square machines

Recovered from Codex session `01a07e50-4534-7a93-bc4f-afeb6693c22f` (2026-09-07).
The editable model is `interplanetary-logistics-v2.blend` in `iln-blender-assets-v2.zip`.
Local source package: `/Users/luan/projects/codex/2026-09-07/i/outputs/iln-assets/`.

The eight body/emission sheets have 64 frames in an 8×8 grid, each 192×256 pixels.
Both layers use 30 fps while idle and 60 fps while active. Scale is 0.625; vertical
shift is -0.5656854249492381 tiles. Shadows are separate 384×256 sprites. Emission
is precolored and uses neutral tint with additive glow.

`thumbnail.png` was made with the built-in imagegen tool using the recovered
entity studies and the previous thumbnail as references, then resized to 512×512.
Final prompt:

> Use case: logo-brand. Create the replacement square thumbnail/logo for the Factorio mod Interplanetary Logistics Network. Image 1 is the authoritative reference for the actual new provider and requester machines; preserve their recognizable oxide-red TX and olive-green RX industrial bodies, circular teleportation irises, copper hardware, cyan coolant tubes, hazard stripes, and orange/green energy cores. Image 2 is the old mod thumbnail being replaced, for context only. Compose a bold readable premium game-mod icon: both actual machines arranged prominently together, with a subtle orbital arc suggesting interplanetary transport, against a deep charcoal industrial-space backdrop. Detailed rendered Factorio-compatible industrial art, crisp silhouettes, restrained glow. Big simple title 'ILN' at the top; no other text. Entire artwork fills a square 1024x1024 canvas, keep machines fully in frame, legible at 144px thumbnail size. Avoid inventing different machinery, excessive particles, thin decorative borders, or tiny text.
