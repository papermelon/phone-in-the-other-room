# Shared-text safety — 30 September 2026

The founder authorized a narrowly configured OpenAI Moderation API integration. Implementation is local; production activation and native distribution are separate. General free-form chat remains a future feature. The current gate covers submitted party names, Shepherd display names, Campfire intentions/check-in notes, legacy shared app display names, Global profile text and the canonical name of a sheep sent to visit a party. Login handles and existing historical content are not retrospectively sent for moderation.

## Policy

Use `omni-moderation-latest` at `/v1/moderations`, without a generative model or new SDK. Ignore the overall `flagged` value and unrelated sexual, violence and self-harm scores. Ordinary swearing and identity discussion are not separate rejection rules. The launch policy is:

| Category | Ask author to review at | Reject at |
| --- | --- | --- |
| hate | 0.50 | 0.95 |
| hate/threatening | 0.40 | 0.85 |
| harassment | 0.60 | 0.97 |
| harassment/threatening | 0.40 | 0.85 |

These scores are signals, not probabilities or proof of misconduct. Thresholds are provisional until the live language corpus and human assessment pass. A warning allows the author to confirm that exact submission; the server binds confirmation to authenticated owner, endpoint, command identity and all checked text. It rechecks the text and cannot use that confirmation to bypass a rejection. There are no automatic account bans. Existing Block/Report controls remain available; staffing reports is a separate operational responsibility.

## Consent and failure behavior

- Before the first external check, the native app explains the OpenAI processing and requests permission. Version 1 is stored per immutable account on that iPhone. Each checked request carries that version and owner; the authenticated Edge gate rejects missing/mismatched authority before contacting OpenAI. This is an explicit per-request processing grant, not a new party/public-audience agreement. It also covers already-pending text previously chosen for sharing. Older clients cannot silently authorize processing.
- Settings → Privacy & data can withdraw future permission on that iPhone. In-flight checks may finish. No shared audience widens, no private Nights reflections or private Farm document is submitted, and account identifiers, passwords, account email addresses and raw Health samples are not attached to requests. Global's already-disclosed profile text can include session/history display strings with dates/times. Text that people themselves choose to share is still included.
- Consent/review pauses retain the exact queued change. Declining removes that pending submission and leaves editor state alone. A definitive rejection removes the queued change and explains rewording. Missing key, timeout, provider failure, malformed results or throttling prevent a new write and leave the change retryable. A previous attempt may already have been accepted if its acknowledgement was lost; outage copy therefore asks for a retry to confirm sharing. Previously published text is not withdrawn by a failed check. Local timers/rewards, ending sessions, withdrawals, blocking, reporting and preset support do not require an external text check.
- Every whole text field is checked; fields are packed into bounded chunks without truncation. Profiles retain their existing one-megabyte envelope limit. The external/admission deadline is eight seconds; unusually large profiles can remain pending if that deadline is exceeded. The service-only admission RPC uses the existing rate bucket at 30 checked submissions per account per minute. Neither it nor the sheep-name lookup is callable by ordinary clients.
- Sheep visits read only the chosen sheep's canonical name from the caller's saved Farm. The write transaction locks/rechecks it against the moderated name, preventing a concurrent rename from publishing unchecked text. Internal binding fields are excluded from the original idempotency hash; existing receipts and service-only SQL harnesses remain compatible.
- Logs/errors do not contain submitted text, provider response bodies, credentials, scores or rejection categories. The native transport maps safe error codes and bounded opaque review tokens. No rejected-text archive or separate moderation inbox is added.

Official OpenAI documentation currently describes the moderation endpoint as free and lists no training, abuse-monitoring retention or application-state retention for `/v1/moderations`. This endpoint-specific behavior is distinct from general API defaults. Recheck before rollout: [moderation guide](https://developers.openai.com/api/docs/guides/moderation), [data controls](https://developers.openai.com/api/docs/guides/your-data).

## Activation and validation

1. With explicit deployment authorization, apply `20260930130000_shared_text_moderation.sql`, then deploy both `night-flock-command` and `campfire-global`. The earlier local Wind Down check-in migration must also be deployed if not already installed. Keep `SHARED_TEXT_MODERATION_ENABLED` absent/false during preparation.
2. Configure a dedicated **server-only** `OPENAI_MODERATION_API_KEY` through Supabase secrets; never put it in the app, repository, chat or logs. No key is configured in this task's shell. Run `node supabase/scripts/evaluate-shared-text.mjs --live` with that environment variable against the repository's synthetic corpus. Correct false positives/misses and have fluent speakers review local-language examples before activation.
3. Publish the updated privacy disclosure and distribute the native consent/review UI before switching `SHARED_TEXT_MODERATION_ENABLED=true`. Old clients will then receive a safe consent-required error rather than sending their text to a provider without permission. Missing key while enabled fails closed; an explicit operator rollback to false disables new checks and must never be described as active protection.
4. On disposable accounts, verify consent/withdrawal on both devices, warning confirmation, rejected notes retaining drafts, Global profile rewording, offline/relaunch replay, account switching and a forced provider outage. Also verify session endings and sharing withdrawal during that outage. Confirm operational report ownership/support contact.

Run local checks per AGENTS.md. The [validation record](../evidence/shared-text-moderation-20260930/validation.md) distinguishes deterministic policy/transport tests from unverified live model behavior. Expanding into free chat should reuse this server gate at its new publishing boundary; it is not protected merely by using the native client.
