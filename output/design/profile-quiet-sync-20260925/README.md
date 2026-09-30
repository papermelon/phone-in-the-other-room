# Quiet Profile sync — 25 September 2026

Automatic account sync remains enabled. The signed-in card uses a stable Farm sync heading and last-confirmed-save timestamp, without a routine loading animation. Loaded presentation and retry errors remain visible until a request supplies a result. Initial authentication/consent and actionable failures retain feedback.

Validation: generic Simulator build passed; 1,138 app tests and 91 isolated Farm tests passed. The final preview-only metadata correction was rebuilt successfully. Logs: `/tmp/profile-quiet-build.log`, `/tmp/profile-quiet-app-tests.log`, `/tmp/profile-quiet-farm-final.log`, `/tmp/profile-quiet-fixture-build.log`. `git diff --check` passed.

Inspected `idle.png` and `syncing.png`: matching card and detail positions with no loader. `large-text.png` checks accessibility-size wrapping. These use the existing isolated Screenbook fixture, not a real account or backend. No physical-device/live-sync verification or distribution was performed.
