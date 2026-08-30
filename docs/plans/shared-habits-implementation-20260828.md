# Shared habits and lifetime history — implementation contract

2026-08-28. The founder authorized implementation of the remaining summaries, archive,
backend rollout and updated beta. This record supersedes the earlier independent-slice
deployment exclusion, but does not assert completed implementation or device acceptance.

## Candidate

Saved checkout `codex/night-flock-mvp`, starting HEAD
`cce766d1840a850a23d5c47e4a542203c26a728b`. Preserve all inherited work.
The 1,116-file baseline is `/tmp/counting-sheep-shared-habits-20260828-170406/baseline/`.

The CLI-linked project matches Debug configuration, **not Release**. An explicit Release
project migration audit confirms production is at `20260825110000`; membership sharing and
social avatar migrations are pending. Do not run an unqualified linked deployment.

## Product contract

- Adults, one explicit agreement per party, no field-toggle matrix. Joining without Health
  data remains valid. OS authorization is a separate contextual action.
- Agreement visibly identifies session updates and available derived sleep duration, current
  and future group members, retention while the party exists, ordinary leaving, and deletion.
- Existing members must affirm the expanded agreement. Their earlier retained **group-shared**
  records may migrate only with that affirmation. Do not upload private prejoin records or
  enlarge an absent former contributor's earlier agreement.
- Ordinary leave stops new publication and access immediately on the device, with remote
  completion shown as pending offline. Approved prior contributions remain in the archive.
- Accessible withdrawal/deletion works after leaving, without rejoining. Account deletion
  removes retained contributions. Dissolving a party removes its archive. Hosts receive an
  explicit dissolve-and-leave action, never silent deletion of everyone else's party.
- Later joiners can page through all retained, consented group history. Seven/thirty-night
  summary windows are not retention limits. Expired/deleted records cannot be reconstructed.
- Home hero, animation, four tabs, protection/session authority and independent rewards stay
  unchanged. No competition scores or remote leader control are introduced.
- The 18:20 request was implemented as a compact timing disclosure above the hero. The
  founder clarified at 20:37 that the older bordered Tonight design is preferred, including
  bedtime/wake time and Before bed/After waking inset cells. Restore that design and the
  prominent time-appropriate green start card, retaining current art and social structure.
  Do not restore obsolete combined quiet-minute calculations or the old tab arrangement.

## Data and trust

1. Add a separately versioned shared-habits capability; unknown/old servers receive no new
   fields. Maintain strict validation and authenticated, caller-derived service RPCs.
2. Keep a separate private archive with per-party agreement/membership epochs, publication
   revision, source identity and bounded historical name/avatar snapshot. It must not depend
   on the active-only 90-day stream's retention or current member profile for attribution.
3. Server checks caller, current membership, accepted contract and epoch at write time.
   Client checks at production, queue and send. Account recovery/reset invalidates stale work.
4. New nightly anchors preserve the intended-bedtime date and time zone at plan creation;
   legacy unknown anchors remain dated activity and do not become nightly statistics.
   Phone Away has its own activity date. Sleep uses an explicitly described contributor-local
   night-ending date, stable across later device-zone changes. Do not transmit exact schedules
   to label a night. Exclude samples spanning the agreement cutoff from first publication.
5. Share derived sleep minutes only: no raw Health samples, stages, source names, exact sleep
   intervals, private reflections, purposes, routines, opaque app tokens or report contents.
   Missing data is unavailable, not zero or misconduct. Late corrections are idempotent.
6. Period summaries cover fixed contributor-local 1/7/30-night windows, with available-night
   counts. Arithmetic means use available eligible nights only; do not infer adherence from
   missing sessions. Deduplicate legacy round/stream/archive sources. Show dates and freshness.
7. Protection evidence is app-recorded apply/clear/failure evidence, not independently attested
   continuous enforcement, physical separation, app identity or Screen Time usage. Keep it
   distinct from Wind Down quiet minutes and Phone Away activity. No inflated combined total.
8. Exact-app Singapore sharing is **documented unsupported by the current public customer
   route**: Apple restricts approvedWithDataAccess and activityData export to EU customers.
   Development availability elsewhere does not qualify. Implement truthful unavailable state;
   do not extract report contents, use private APIs or substitute manual categories.

## Access, lifecycle and deletion acceptance

- A preflight local leave/withdrawal journal suppresses reads and publication before network
  work. Legacy account-wide fan-out must also stop while a destructive action is unresolved.
  Do not drop unrelated local rewards or turn a network failure into a successful remote leave.
- Rejoin creates a new publication epoch. Tombstones prevent deleted rows being resurrected
  by retry/backfill and prevent reward replay; minimal idempotency markers contain no metrics.
- Archive pagination is deterministic with bounded pages. Server aggregates cannot be computed
  from only the first 100 rows. Blocked/unauthorized readers cannot query archived records.
- Realtime carries sanitized invalidation only; refetch canonical state. Visible social views
  may use bounded fallback refresh; no network polling or social UI in Active Wind Down.
- No genuine participant Health/app data is uploaded during testing without that participant's
  in-app agreement. Local SQL fixtures and UI fixtures are synthetic.

## Verification and rollout

Fresh Sol commitment review: proceed after six concrete refinements. The implementation lanes
now include explicit bounded legacy migration; stable night-ending and bedtime anchors; durable
offline leave blocking even account-wide legacy fan-out; cross-epoch deletion tombstones;
consistent mutation locking; and explicit dissolve-and-leave cleanup. Existing rewards stay in
their original ledger. The initial 1,116 baseline files were unchanged during consultation;
the reviewer ran no mutations. Its verdict is not final implementation acceptance.

The founder explicitly approved a new build number and Health purpose text. Live App Store
Connect inspection on 28 August confirms build **35** is the latest, processed and Testing in
both existing Internal QA and QA groups. The next candidate will be **36**. No new tester or
group is needed. This audit does not establish which build is installed on any phone.

Configured Terra High owns implementation; parent reviews actual diffs and reruns validation.
Fresh Sol consultation precedes the contract and a fresh final review follows all corrections.
The host is unrestricted; reviewer read-only behavior is checked by hashes, not claimed as
OS-enforced isolation.

Required: legacy decoding; strict Edge payload tests; SQL/RLS current/outsider/former/late member,
rejoin, pagination >100 rows, cutoff, correction, deletion and dissolution tests; Shared period,
date/DST/travel, partial/no-data and queue-fence tests; full simulator build/unit suite; native
small-screen/accessibility navigation. Physical Health, Family Controls, three-account archive
access and upload/processing remain separate evidence, never inferred from fixtures.

Deploy only reviewed migrations/functions to the explicit Release project after a scoped dry
run. Reconcile purpose strings, privacy policy and beta review notes. Build-number/Health-purpose
metadata changes are approved under AGENTS.md. No new entitlement or target is planned.
An uploaded beta is not evidence that the founder's phone installed it. App Store public release
is not included in this beta update.

## Primary platform references

- [Apple data-access eligibility](https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess)
- [Apple activity export](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata(filteredby:using:))
- [Apple report sandbox](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport)
- [Apple privacy and Health rules](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Singapore data protection obligations](https://www.pdpc.gov.sg/data-protection-obligations)

These sources guide the engineering boundaries; this document is not legal certification or
an assertion of Apple approval for the proposed social feature.
