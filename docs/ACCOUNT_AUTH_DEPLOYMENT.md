# Account authentication and Farm sync deployment

This runbook prepares the additive account-password and account-owned Farm backend. It does
not authorize deployment, client activation, or a claim that a Farm is saved. Deploy only after
the owning app changes have passed the account-transition, local-owner partition, and physical
device gates in the account-owned Farm plan.

## Backend contract

`farm_save_v1` and `farm_save_revision_v1` stay Apple-only for old clients. New clients use
`farm_account_sync_v1` after a deliberate `{"action":"accept"}`. Its initial
`{"action":"status"}` response contains `accepted`; after acceptance, its `lookup`, `put`,
`select`, and `delete` payloads and revision/generation behavior match the established Farm
contract. Retained-copy reads use `farm_account_sync_revision_v1`. Both new RPCs accept a
nonanonymous account that has a confirmed email or an Apple identity. The immutable Auth UUID
remains the sole Farm owner.

`account_username_v1("get")` returns the caller's normalized username or null.
`account_username_v1("claim", username)` is available only after verified identity, accepts a
case-insensitive 3–24-character ASCII handle matching `^[a-z][a-z0-9_]*$`, and claims it
transactionally. A claimed name cannot be renamed by this version. `account_username_unavailable`
means that the client should let the verified user choose another name; it must not report a
successful registration.

`POST /functions/v1/account-password-login` accepts JSON
`{"username":"…","password":"…","captchaToken":"…"}`. A leading `@` is allowed for
login only. Success is the normal Supabase Auth session JSON (`access_token`, `refresh_token`,
`expires_in`, `token_type`, `user` where supplied by Auth), so the native client may adopt it
through the approved Supabase Swift session API. Invalid/unknown usernames and incorrect
passwords both return `401 {"error":"Invalid username or password"}`. This endpoint never
returns a resolved email and must never log a request body, credentials, tokens, or its private
lookup result.

Registration and recovery remain native Supabase Auth calls. For signup, call email/password
`signUp`, then enter the emailed code through `verifyOTP` with email `type: signup`; only then
claim the username. For recovery, use Supabase's password-reset email flow and enter the code
through `verifyOTP` with email `type: recovery` before changing the password. Password or Apple
method linking uses the existing native linked-identity flow and must assert the same UUID before
activating its Farm.

With secure email change enabled, Supabase sends confirmation to both the current and proposed
recovery email. The app must make both code-entry steps clear, verify the code against the address
that received it using email `type: email_change`, and keep the original email active until both
confirmations succeed. Password reauthentication sends its own code before a non-recent session
can change a password; it is not a password-reset code.

## Required production settings

1. Apply migration `20260907110000_account_identity_and_farm_sync.sql` to a disposable project,
   run `supabase/tests/farm_save_test.sql` and `supabase/tests/account_identity_test.sql`, then
   perform a two-account staging exercise. Do not overwrite or edit historical migrations.
2. In Supabase Auth, enable email/password signup and email confirmations, require at least a
   12-character password containing lower/upper case letters and digits, enable secure password
   changes, and set a production resend interval. Confirm Apple stays configured with the app's
   production credentials. `supabase/config.toml` enables manual identity linking only for local
   native testing. Before enabling hosted staging or production linking, prove that linking an
   Apple identity and adding email/password both retain the same Auth UUID and Farm owner; record
   the before/after UUIDs from a disposable staging account. Do not enable hosted account-linking
   behavior without that UUID-preservation evidence.
3. Configure a production SMTP sender and deploy the confirmation, recovery, email-change, and
   reauthentication templates from `supabase/templates/`. They use `{{ .Token }}` because native
   clients enter one-time codes; do not replace them with unallowlisted redirect URLs. Verify sender domain, SPF/DKIM/DMARC,
   delivery, expiry, replay, link-scanner behavior, and redaction in the mail provider logs.
4. Deploy `account-password-login` with `verify_jwt = false` and set the server-only secret
   `ACCOUNT_PASSWORD_LOGIN_RATE_LIMIT_SECRET` to a high-entropy value. Set optional integer
   `ACCOUNT_PASSWORD_LOGIN_IP_LIMIT` (default 20), `ACCOUNT_PASSWORD_LOGIN_IDENTIFIER_LIMIT`
   (default 5), and `ACCOUNT_PASSWORD_LOGIN_WINDOW_SECONDS` (default 300). The function fails
   closed if its rate-limit secret or client IP is unavailable.
5. Configure Supabase Auth CAPTCHA in the hosted dashboard and set
   `ACCOUNT_PASSWORD_LOGIN_REQUIRE_CAPTCHA=true` only after it is live. When enabled, the
   endpoint rejects missing tokens and forwards `captchaToken` to Supabase Auth for validation.
   Confirm the trusted edge gateway overwrites `X-Forwarded-For`; do not deploy behind a proxy
   that lets callers choose the value used for IP limiting.
6. Restrict function logs and database access to operators who need them. The service-role key,
   rate-limit secret, SMTP credentials, CAPTCHA secret, tokens, and password bodies must never
   enter source control, analytics, crash reports, support exports, or client configuration.

## Release gates and rollback

Keep the new client capability disabled until staging proves: password-only, Apple-only, and
linked-method users retain one UUID; unknown versus wrong credentials are indistinguishable;
concurrent username claims choose one winner; account A → sign-out → B never exposes A's Farm;
offline/pending Farm work and deleted-generation fences survive relaunch; and an old Apple client
continues using `farm_save_v1` unchanged. Exercise code-first signup and recovery on physical
devices, including autofill, cold launch, resend, expiry, and password reset session revocation.

If activation must stop, withhold the client call to `accept` and disable the function route or
its gateway. Do not remove the migration, delete `account_sync_acceptances`, or downgrade
owner-scoped local state: accepted accounts may need the RPC to recover an existing Farm.
