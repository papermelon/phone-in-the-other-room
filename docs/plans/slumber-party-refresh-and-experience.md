# Slumber Party refresh and experience draft

7 September 2026 · Local source draft, not deployed or distributed.

## Intended experience

People and their shared moments lead the screen. Background reads do not turn a large
button into a persistent “Refreshing…” label. One refresh control in the party header
requests current party activity and shared summaries. Existing sharing agreements,
server capability gates, consent boundaries, rewards and account ownership are preserved.

A failed read belongs to the affected party and section. It clears when that section
loads successfully, without clearing an unrelated failed command. Recoverable read errors
offer a retry. Invalid requests do not promise that repeating the request will fix it.
Support details use the failure's reference, never an earlier successful command's ID.

## Implemented draft

- Separate party-detail and shared-summary read failures from the global action banner.
- Show a failure instead of the endless opening placeholder when the initial party read fails.
- Remove the large summary refresh button and routine background observation text.
- Refresh both current party activity and summaries from the header, using a fresh party read
  rather than reusing the selected party cursor.
- Keep the existing in-flight summary serialization through reconciliation. Attempt identifiers
  prevent an old task's cleanup from clearing a replacement task after account/party reset.
- Name failed v4 commands: profile, invitation, cheer, shared moment, and other actions.
  Distinguish a confirmed saved action followed by a failed read from a rejected action.
- Put the identity above member metrics so values can use the card's full width. Keep
  accessibility-sized metrics stacked. Replace repetitive missing-data labels with
  “Not shared yet”; label dates as “Night ending”, not a claim of a completed ritual.
- Keep 7/30-night sleep averages expandable. Move repeated timing, averaging, retention and
  verification explanations into details disclosures. Preserve those explanations and history.
- Add retryable and rejected-request previews, including large text.

## Validation

Validation on 7 September:

- `xcodebuild build -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'generic/platform=iOS Simulator'` — passed on the final source.
- `xcodebuild test -project PhoneInTheOtherRoom.xcodeproj -scheme PhoneInTheOtherRoom -destination 'platform=iOS Simulator,id=71CF8F3E-9E9A-449D-93A8-B73F64869A5E'` — 876 tests passed, zero failures. The final view-model-only cleanup preserved the tested Shared/test sources; the app was rebuilt afterward.
- Changed-file whitespace checks passed.
- Visual acceptance is pending: the dedicated Screenbook simulator repeatedly failed to launch
  the preview, including after restart, reporting NSPOSIXErrorDomain code 3 / no process handle.
  Large-text previews exist but are not claimed visually accepted.

Logs are under `tmp/slumber-party-review/`. Four regression cases cover rejected-request retry policy,
transient failures and their request references, missing server references, and a saved command
whose follow-up read failed. These are not end-to-end network or physical-device tests.

## Remaining acceptance

- Identify the original server rejection using the affected build and correlated hosted logs.
  The old UI could show the wrong support reference, so the screenshot ID alone is insufficient.
- Exercise delayed summary reads, reconnect, successful retry, party/account switching,
  authentication recovery and a second member's update on controlled devices.
- Review the visual draft on small screens and with VoiceOver and large text. Simulator
  fixtures demonstrate layout, not live sharing or physical protection.
- Extend operation ownership to remaining global command/outbox errors. The first pass scopes
  party/summary reads and improves v4 command titles; it is not a rewrite of every recovery lane.
- Review archive pagination failures separately: the existing cursor recovery discards the
  snapshot and retries the first page for all cursor failures, including network errors.

No backend changes, production activation, commits or distribution are included in this draft.
