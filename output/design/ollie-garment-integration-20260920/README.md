# Ollie garment integration review — 20 September 2026

The six attached motion sheets were captured from the DEBUG Shop wardrobe fixture after the
shared neckwear renderer migrated Moon Kerchief, Brass Farm Bell, Clover Collar, Sunrise Scarf
and Star-Keeper Cape.

Each sheet includes six Home frames, six run frames, poses 2–11 and Farm idle. The renderer
uses the same neck-left, neck-right and bib-tip landmarks across Home, Farm, Fetch and active
journey sprites; tucked cloth is clipped to Ollie's silhouette and the original textured ruff
is restored over the neckline. The cape has a behind-body panel plus a fitted shoulder panel.

Validation: arm64 iOS Simulator build succeeded; full suite passed with 1,104 tests and zero
failures. These captures are Simulator visual evidence, not physical-device acceptance.
