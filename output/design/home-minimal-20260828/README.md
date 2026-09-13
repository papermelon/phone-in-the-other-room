# Counting Sheep — minimalist Home design study

2026-08-28. **Design comparison only. Native implementation and verification are tracked separately.**

Open `index.html` locally, or run `python3 -m http.server 8768 --bind 127.0.0.1`
from this directory and visit `http://127.0.0.1:8768`. The preview has no backend,
tracking, external fonts, dependencies, account access or real session actions.

## Direction confirmed by the founder

- Personal Ollie leads, with a visually connected group preview. Shared scene is now deferred;
  shared Farm is a possible later exploration.
- Restore Ollie's size, animation and welcoming presence.
- Very minimalist hero: only 1–3 home ornaments, no complete room illustration.
- Member avatars/statuses plus one recent highlight; full history in Slumber Party.
- Compact timing with expandable details. Keep phone-away start and phone-wake understandable.
- More than a repeating head tilt: ears back, a relaxed flop, a few seconds resting, then rise.
- Photo-based ear pose and tongue greeting are approved references for animation in both Home and Farm.
- Keep “Night 2 of 7” on one line, allowing the whole label to move below members when space is tight.
- Explore the personal Shepherd as a companion, not a replacement for Ollie. Art refresh timing is open.

## Current comparison state

- `personal-home.png` is the latest Ollie-alone current preview and selected reference.
- `personal-shepherd.png` and `personal-shepherd-320.png` are centered, optional Shepherd-pair comparisons; the toggle remains off by default.

## Deliverables

- `index.html`, `style.css`, `preview.js`: interactive personal/shared comparison, selectable
  sample highlights, timing disclosure, eligible Wind Down state, larger-text simulation,
  existing head tilt and a playable body-timing study.
- `personal-home.png`: phone-size personal mockup; two home ornaments (lamp/window).
- `shared-home.png`: phone-size shared alternative; one small window, original character
  assets composed into an illustrative group. Placement does not represent live co-presence.
- `assets/home-ornaments.png`: selected generated ornament concept.
- `assets/ollie-tongue-welcome-study.png`: **approved** tongue greeting pose with original pointed ears.
- `assets/ollie-ear-reference-study.png`: **approved** ear pose based on supplied dog photos.
- `assets/ollie-flop-body-timing.png`: earlier sheet used ONLY for body timing. Its ear treatment
  is unapproved. The player holds the rest for three seconds and uses a distinct rise sequence.
- `prompts.json`: exact built-in image-generation prompts and output provenance.
- Header comparison uses the supplied logo unchanged, not a newly generated or cleaned logo.
- Optional personal Shepherd toggle uses existing art; it hides the lamp to keep just one ornament.
- `header-supplied-logo.png`, `personal-shepherd.png`: comparison screenshots, not selected defaults.
- Implementation sequencing and acceptance checks: `docs/plans/home-hero-approved-direction.md`
  in the repository.

## Rejected / unresolved artwork

The full-room background was rejected and is not used. The initial ears projected sideways;
the next attempt made floppy forward ears; another made an almost earless round head. All were
rejected. The last two rejected variants copied earlier are retained as
`ollie-flop-ears-back-study.png` and `ollie-ears-back-pose.png`, **not consumed by this preview**.
The original app assets have not been overwritten. The founder has now accepted the photo-based
ear pose and tongue greeting; use those exact candidates as the references for new frames.

The initial transparency request returned RGB with a painted checkerboard. The body study uses
a generated dark-background version instead and is not export-ready. Its grid also required
prototype-only display rectangles; files were not programmatically retouched. Production needs
consistent face/body proportions, ground registration, true alpha, additional in-betweens,
and a matching neutral return pose. Tongue and ear candidates remain separate stills rather
than pretending to be a finished coherent animation.

## Recent-highlight options and truthful boundaries

| Option | Example sample copy | Existing data / qualification |
|---|---|---|
| Completed Wind Down | Moss completed 30 quiet minutes of Wind Down. | Shared activity kind/status/rounded minutes. Only factual wind-down minutes, not overnight or sleep time. |
| Completed Phone Away | Moss completed 20 quiet minutes of Phone Away. | Shared terminal activity. Never call an early-ended session completed. |
| Received cheers | 2 warm waves for your last Wind Down. | Canonical received counts for the exact activity. Aggregated counts do not identify individual senders. |
| Round milestone | Your group finished its seven-night round. | Actual round lifecycle. Completion of a round is not proof all members completed seven sessions. |
| Curated Farm spotlight | A look from Moss's Farm. | Current consented presentation snapshot. It cannot support “Moss just found a sheep” or “changed their outfit” without a new event. Not mocked yet. |
| Nothing recent / offline | No recent shared moments / Showing the last shared update. | Distinguish empty history from unavailable/stale transport. Never infer nonparticipation from missing data. |

Recommended selection policy: one current, relevant item; stable during a visit; no auto-advancing
carousel. Prefer received encouragement or a recent factual completion, with genuine round events
when relevant. Local seen/dedup state and a freshness threshold would be new presentation work.
Keep groups separate and use the existing eligible/current-member, block and expiry projections.
No purpose, exact personal schedule, Health, selected apps, private Farm inventory or invented
presence is added. Source fields inspected: `Shared/NightFlockV4Models.swift` and the existing
Slumber Party presentation/curated profile contract.

## Motion direction to review

Keep head tilt, tongue greeting and flop/rest/rise as separate actions with long neutral rests.
Proposed greeting: small tongue out briefly, mouth closes before chin rests on paws. The prototype
has explicit replay controls rather than an approved autonomous scheduler. A production scheduler
should avoid immediate repeats, pause while offscreen/backgrounded, respect Reduce Motion and
not introduce new social actions during Active. Rebuild the body sequence using the approved
ear reference, rather than carrying forward the rejected ear geometry. Farm cosmetic overlays
and depth masks must follow each pose. An approved still is not a completed animation set.

## Verification

Browser inspected the 390×844 personal and shared versions, expanded the plan, changed the
highlight to received cheers, toggled eligible Wind Down and larger text, and played the body
study through the held rest and returned sitting pose. Tongue candidate opens correctly.
`node --check preview.js` passed. Browser viewport override was restored. This is HTML concept
verification, not native iOS, VoiceOver, physical-device, social transport or performance QA.

Approval follow-up: checked the round label with larger text at 390 px and 320 px, including
“No shared update” and “Between rounds”; it remains one line within the card without document
overflow. Captured personal, supplied-logo and personal-Shepherd variants at 390×844. Verified
the header selector and the two approved-pose controls. Syntax and referenced-file checks pass.
The 878-path accepted-source manifest still differs only in the same four documentation files;
no existing accepted application source changed during this design pass.

No Swift/backend/target/tab/signing files changed. No deployment, commit or phone build update.
