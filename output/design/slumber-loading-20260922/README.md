# Slumber Party loading recovery — local UI checks

22 September 2026. Production views rendered with the existing offline
`--slumber-repair-qa` fixture on Counting Sheep Shared Farm Small QA (iOS 26.5,
small iPhone/SE layout). No real account or backend calls were used.

- `server-error-small.png`: readable initial error and separate Try again button.
- `offline-small.png`: a known offline error has connection-specific recovery copy.
- `cached-refresh-small.png`: refresh failure retains the Night Owls fixture party;
  the notice explains that the previous update is shown.

The accessibility tree exposed the headings, recovery text, named buttons and party
navigation. Support details initially stayed collapsed; opening it exposed the fixture
request ID. Retry controls use the existing minimum 44-point targets; support text
retains native text selection.

Accessibility 3 text was checked with the timeout fixture. Its complete title, detail
and retry action were present in the accessibility tree, but the native automation did
not scroll the simulator reliably to inspect the full lower card. Full visual scrolling
at large text sizes and spoken VoiceOver remain physical-device checks. This is not an
end-to-end network reproduction or evidence that the original production 500 is fixed.

See [implementation and validation](../../../docs/plans/slumber-party-loading-investigation-2026-09-22.md).
