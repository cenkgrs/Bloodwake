# Background art

Looked up by `OverlayBackground` (`lib/ui/widgets/overlay_background.dart`).
A missing file just leaves the plain dark background — nothing breaks, the
screen is only flatter until art lands. Any resolution works; content is
laid out full-bleed with `BoxFit.cover`, so a portrait-oriented image
(roughly 1080x2400 or taller. `.jpg` works fine, extension just needs to match the actual file) crops best on a phone screen.

| File               | Used by            |
|--------------------|---------------------|
| `shop_bg.png`      | Shop overlay        |
| `level_up_bg.png`  | Level-up overlay    |

`.png`, `.jpg`, and `.webp` all work.

## Arena floor

| File          | Used by                                    |
|---------------|---------------------------------------------|
| `map1.png`    | Gameplay arena floor (ArenaComponent)       |

Repeated as a **seamless tile** across the arena (`ArenaComponent._tileWorldSize`
controls how large one repeat is in world units — currently 500, tuned so a
paving stone reads at roughly human scale next to the player sprite), not
stretched as one scene. Must be:
- square
- tileable on all four edges (no visible seam when repeated in a grid)
- flat/evenly lit, no single focal point or dramatic directional shadow
- same camera angle as the character sprites (3/4 top-down, ~40°), not a
  flat vertical bird's-eye view — otherwise the floor and characters read
  as two different perspectives pasted together

See the prompt used to generate the current one in git history / ask
before regenerating — it encodes all of the above.
