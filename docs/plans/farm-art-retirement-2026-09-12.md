# Paper Farm scenery and artwork retirement

Founder direction: the personal Farm's farms, barns, meadows and related scenery should use
paper-textured illustration, matching the shared-pasture and character direction. This is an
environment-art migration, not a request to replace every icon, typeface or character renderer.
Implementation status: personal background and barn Shop art replaced in their stable slots; original shared meadow preserved byte-for-byte. Four confirmed unused files were removed. See [measured evidence](../evidence/pasture-redesign-20260912/README.md).

## Baseline evidence (before implementation)

`Assets.xcassets` contains 504 files, approximately 60.05 MiB of logical source bytes. Its
`generated_sources` folder contributes about 3.13 MiB. `output/design` contains 134 files,
approximately 56.41 MiB. These are source-directory measurements, not installed app or download
sizes. `project.yml` includes the common catalog for the phone, Watch and Live Activity targets;
compiler behavior, device slicing and actual compiled resources require a build-size inspection.
Design output is outside the catalog and is not declared in the inspected target resource paths.

No explicit asset-retirement register was found in the existing art guidance. Naming an image
unused, deprecated or old does not remove it from disk or from a configured resource catalog.
The older visual-revamp guide places raw sources inside the catalog, while current generation
guidance says working sources belong in ignored `tmp/imagegen/`; new imports should follow the
latter policy. This document starts the candidate register rather than treating a text search
as sufficient proof of removability.

## Replacement and candidate register

| Asset/group | Current observed usage | Disposition |
| --- | --- | --- |
| `farm/farm_background_day` | `FarmPastureView`, onboarding welcome and Shop item preview; also legacy MVP source | Active: replaced with paper scenery; stable slot updates personal Farm, onboarding and Shop consumers |
| `farm/farm_barn` | `FarmShopView` and legacy mock/MVP code | Active: paper barn Shop tile; stable inventory semantics. Image tool did not produce real alpha, so the selected tile intentionally has a cream paper background |
| `farm/farm_fence` | Central slot and legacy MVP reference found | Review fallback/dynamic consumers; replace if retained, otherwise retire after reference checks |
| `farm/farm_hills_side_scroll_test` | Only its own catalog metadata found in scoped repository search; about 2.18 MiB | Retired: PNG and metadata removed after all-target/static/dynamic checks and exact Git recovery verification |
| `farm/farm_shared_meadow_dusk` | Existing shared Farm and prototype paper environment | Active: founder explicitly retained original artwork and wide framing |
| `Assets.xcassets/generated_sources/*` | Two raw generation sheets, referenced by historical art documentation | Retired: both raw sheets removed from runtime catalog; exact committed copies remain recoverable in Git |
| `output/design/*` | Local design work, approximately 56.41 MiB | Keep active work and minimum evidence; identify superseded iterations separately before cleanup |
| Legacy `farm_shepherd_*` PNG bases, masks and fitted hats | Superseded by `ShepherdAvatarView` → `ShepherdStudyCanvas`; unused slot/catalog mappings removed | Retired 23 September: 20 image sets moved to a checksum-verified external archive. Do not use as visual references. See [retirement record](../evidence/legacy-shepherd-retirement-20260923/README.md) |

Complete the register during implementation for scene props, Shop environment thumbnails,
journey backdrops and all other Farm environment consumers. Inspect images visually before
classifying their style. Do not assume every file under `farm/` is scenery or obsolete.

## Art migration batch

1. Establish a coherent paper environment palette and perspective from the approved character
   art and retained shared meadow: terrain, barn, fence/gate, paths, foliage and foreground
   layers. Redraw pixel shapes and edges; a paper-noise overlay alone does not change the style.
2. Keep the refreshed personal pasture and original shared meadow as distinct compositions from the same environment
   family. Keep interactive props separate from scenery; movement and depth need ground anchors,
   unobstructed touch areas and foreground/middle-ground layers.
3. Preserve production Shepherd/Ollie/sheep renderers, cosmetics and ownership IDs. Prefer
   replacing a stable image slot in place when the asset serves the same role. Catalogue/item
   identifiers must not be renamed merely because their art changes.
4. Inspect the image component: `PixelAssetImage` previously forced `.interpolation(.none)`; the implemented allowlist uses high sampling for personal/shared background and barn only.
   Provide appropriate sampling for textured illustration while retaining intentional pixel
   treatment for unrelated assets. Do not globally change every image's sampling blindly.
5. Integrate background/prop replacements into personal Farm, shared Farm, Shop previews and
   other observed consumers. Check small-screen cropping, light/dark, shadows, interaction
   layers and fallback behavior. Retire predecessors in the same completed batch where safe.

## Retirement policy

- **Active:** approved artwork used by release screens or a necessary fallback/compatibility
  mapping. Keep it in the relevant runtime resources.
- **Candidate:** suspected obsolete, experiment or duplicate. Record consumers, replacement,
  provenance and outstanding checks here; the status is not a deletion instruction by itself.
- **Retired:** all consumers are migrated or deliberately removed; dynamic lookup, catalogue IDs,
  previews, Watch/widgets/extensions and fallbacks have been checked. Remove it from runtime
  resources and the working tree once recoverability is established.
- Keep generation working files under ignored `tmp/imagegen/`, outside `Assets.xcassets`.
  Preserve only needed approved masters/provenance and compact evidence outside runtime assets;
  an archive folder inside the catalog is still the wrong place for retired art.
- For an old binary already in a known Git commit, Git history can provide recovery. Verify it
  is committed before relying on that. Uncommitted art may be the only copy; preserve that work
  until its replacement/recovery is established. Never blanket-delete unrelated design output.
- Removing a tracked binary from the current checkout does not shrink existing Git history.
  Rewriting history or changing storage arrangements is a separate operation, not normal cleanup.
- Measure catalog sources and compiled resources separately before/after migration. Verify
  build warnings and actual `Assets.car`/bundle sizes for each affected target; source MiB alone
  do not establish app-size savings. Build affected targets and run the repository merge gates
  for source/rendering changes. The implementation build and resource measurements are recorded in the linked evidence.

Completion means approved replacement scenes in production, obsolete runtime artwork removed,
recoverable provenance, no missing-image/fallback regressions, native screenshots and measured
resource-size evidence. A retirement label alone is not completion.
