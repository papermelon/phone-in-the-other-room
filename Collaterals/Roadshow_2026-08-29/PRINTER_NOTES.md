# Counting Sheep Vending-Machine Collateral Kit

First-pass production kit for the 29 August 2026 roadshow.

## Deliverables

- Hero poster: A2 portrait, 420 x 594 mm trim, 3 mm bleed.
- NFC onboarding poster: A3 portrait, 297 x 420 mm trim, 3 mm bleed.
- Vending card: 90 x 140 mm trim, two PDF pages for front and back, 3 mm bleed.
- Machine labels: A4 proof sheet. Final label dimensions must be updated after the machine is measured.
- Branded booth mockup: visual concept only; not a fabrication drawing.

## Before final print

1. Replace the marked QR placeholder on the A2 poster with the final live App Store or TestFlight URL.
2. Confirm the physical sticker and NFC tag diameters against the card mounting areas.
3. Measure the machine face, button, slot and instruction-panel surfaces, then resize the A4 labels.
4. Ask the printer whether they require PDF/X, a specific CMYK profile, outlined fonts or a different bleed value.
5. Print one card at 100% scale and test-mount both physical items before ordering the full quantity.
6. Test representative blank writable NDEF tags with the release build on a compatible iPhone.

## Art and copy notes

- Real production Ollie art is used for mascot fidelity.
- Legacy generic sheep art is excluded. Future sheep collateral should use the current named `*_wool_ready` production assets.
- The generated booth environment is a concept layer only. All visible brand copy was applied separately for accuracy.
- The A2 hero and A3 onboarding poster use separate generated paper-collage illustration layers. All text, Ollie art and QR areas remain controlled layout elements.
- Copy follows the current app labels: `Put phone away`, `Protection & tags`, `Start with an NFC tag`, `Set up NFC tag`, and `Screen-Free Morning`.

## Working palette

- Warm cream: `#FAF7EA`
- Paper: `#FFFDF6`
- Ink: `#1F201A`
- Moss: `#587744`
- Dark moss: `#334B32`
- Amber: `#EBAF38`
- Lavender: `#7B73A9`
- Light lavender: `#C9C1DA`

The editable source is `source/build_vending_collateral.py`.
