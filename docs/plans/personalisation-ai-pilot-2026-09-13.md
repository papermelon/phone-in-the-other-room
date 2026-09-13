# Personalisation AI pilot — proposal only

13 September 2026. **No AI endpoint, consent flow, credentials, paid calls, quota
service, or deployment was added.** The implemented local loop is described in
[the local delivery record](meaningful-personalisation-implementation-2026-09-13.md).
This proposal and its offline harness are separate from production behavior.

## Recommendation and comparison

Keep the local loop as the default. Its selected goals propose a small activity;
explicit feedback can produce one reviewable activity or cue adjustment.
Custom wording stays custom and is never guessed into a category. This is useful
offline, understandable, and costs no API tokens.

Evaluate **user-requested interpretation of personal wording** first. For example,
“After my night shift, I want a moment that belongs to me” could offer “Time for
myself,” with a custom/unknown alternative, which the person must confirm. The
value to test is fewer effortful category/wording edits without distorting intent.
The local comparison preserves the personal answer and asks the person to choose
an activity. A valid custom answer counts as success; forcing classification does
not. Do not call the model merely to make existing template prose sound warmer.

A secondary evaluation may restate a single already-eligible local adjustment or
summarise up to three selected self-reports on request. Local code selects eligible
actions and evidence first. AI cannot invent a trend or introduce an adjustment
that the rules excluded. Ship only an independently useful, measured improvement;
do not bundle all three experiments or add a chatbot.

## Minimal request and consent

Before the first request, show the exact short text/notes selected for sending and
name OpenAI as the processor. Explain the purpose, useful local alternative,
provider/backend retention, and what deletion can and cannot remove. Use a separate
versioned AI opt-in plus an explicit “Interpret these words” action. No prechecked
training/data-sharing options. Declining, switching off, or being offline preserves
the entire local ritual. Guest mode remains local; the initial server pilot
requires an authenticated account and must say so without blocking the routine.

Send only mode, up to 120 characters of selected goal wording, optional bounded
plan constraints, at most three explicitly selected notes (240 characters each),
opaque request-local evidence labels, and eligible action IDs. Prefer obstacle
choices/coarse counts over notes where sufficient. Preview and omit unnecessary
sensitive text. The server holds the authenticated owner and consent/plan binding;
OpenAI does not need the account UUID. Never send Health, app/category tokens or
identities, placement/access logs, exact run times, notifications, emergency-exit
text, social data, or the Farm document. Logs must not include prompts or outputs.

Use foreground Responses requests with `store: false`, no conversations,
`previous_response_id`, background mode, tools, files, or hosted history. OpenAI
states API data is not used to train models by default unless the customer opts in.
Default abuse-monitoring logs can contain content and be retained up to 30 days,
with exceptions for law and protecting services/third parties. `store: false` is
**not zero retention**; do not promise immediate deletion from abuse logs. Verify
project settings and any approved retention arrangements before consent copy is
final. [Official data controls](https://developers.openai.com/api/docs/guides/your-data)

Proposed backend retention, requiring approval before implementation: an encrypted
idempotency result cache for up to 24 hours; operational cost/status records for
90 days; no personal request/response application logs. Disable cancels future
requests, clears the local AI cache, and rejects late responses. A delete action
removes local AI output and owner-scoped cached backend content; account deletion
uses the same path. Minimal billed-cost counters must remain until their budget
period closes so deletion cannot reset quotas. Explain this and the provider log
boundary plainly. Cross-device personalisation sync is a separate payload and
consent decision; do not add these fields to Farm sync or Slumber Party.

## Server and response boundary

Use the existing authenticated Supabase transport and an additional bounded Edge
Function, with built-in fetch to OpenAI. The existing backend authenticates requests
and uses server-owned secrets; it currently has no personalisation AI route. Keep
the API key only in server secrets. Validate the JWT/verified immutable owner, not
a caller-supplied owner ID. Server-controlled model, prompt, schema, limits and
quotas; no new iOS/OpenAI SDK is needed.

The [proposed strict schema](../../scripts/personalisation-eval/response.schema.json)
and [prompt](../../scripts/personalisation-eval/prompt.md) are evaluation assets.
Use Responses `text.format` with JSON Schema and `strict: true`. All fields are
required, nullable fields represent absence, and additional properties are
forbidden. Application validators additionally enforce string/count bounds,
mode-compatible goal kinds, currently eligible action IDs, exact evidence sets,
one question maximum, and no action in `no_suggestion`. Check refusal, incomplete
responses and API errors before parsing. Structured output is a formatting
contract, not proof of truth or safety.
[Official Structured Outputs guide](https://developers.openai.com/api/docs/guides/structured-outputs)

After validation, bind the response again to request identity, owner, consent
version, goal ID, plan revision, evidence contents and expiry. Discard after any
change, sign-out or switch, even if a network cancellation arrived too late. Show
a short evidence-grounded reason, never chain-of-thought. The person can accept,
edit, dismiss or keep the custom wording. All actual changes use the existing
reviewed local path; model output has no access to timers, shielding, rewards,
settlement, account controls, automatic starts or reminders.

## Offline behavior, latency and hard budget

Return the local proposal or no suggestion for offline state, timeout, refusal,
invalid evidence/schema, revoked consent, rate limit, provider outage, key rotation,
and exhausted quotas. Keep Done/cancel reachable while waiting. Target median
under 2 seconds and p95 under 5 seconds; cancel the foreground attempt at 6 seconds.
These are proposed acceptance targets, not measured performance. No automatic
retry in the initial pilot; an explicit retry still consumes a reserved request.

Propose 50 consenting users, four total attempts per user per calendar month in
UTC, no more than one attempt per rolling 24 hours across every AI entry point,
and **$5 USD total pilot cap**, subject to separate founder approval. This is a
proposal, not permission to spend. All models and retries share the cap.

The server must atomically reserve both a user request slot and a pessimistic
cost amount before fetch. Use one database transaction/row lock over user-period
and global-pilot ledgers, with unique `(owner, idempotency_key)`. The same key and
payload reuses an in-flight/cached result; a different payload with that key is
rejected. Global `spent + reserved + worst_case_cost` must not exceed the approved
cap. Parallel requests cannot race past it. Fail closed for AI if the quota store
is unavailable. The local ritual stays open.

Bound the complete serialized prompt/schema/user payload by UTF-8 bytes; reserve
an audited worst-case token allowance including envelope overhead, e.g. 16,000
input and 400 total billed output tokens. Set `max_output_tokens: 400`; Luna can
use `reasoning.effort: none`. Reserve Luna at its higher cache-write input rate:
`16,000 × $0.25/M + 400 × $1.20/M = $0.00448`. A mini comparison reserves
`16,000 × $0.75/M + 400 × $4.50/M = $0.0138`. Reject oversize requests before fetch.
Pin the rate table to model/version; halt if pricing/usage is unknown.

Reconcile actual input/cached/cache-write/output/reasoning usage from provider
usage and release only proven unused reservation. If timeout/transport failure
leaves billing uncertain, charge the full reservation and keep the user slot.
A crashed worker must not silently refund possibly spent tokens. Persist a lease
and reconcile uncertain reservations conservatively. Kill switch is checked before
reservation and immediately before dispatch. Alerts supplement this enforced cap.
Do not rely on a dashboard project budget as the hard stop, enable auto-recharge,
or buy credits. Test parallelism, duplicate keys, crash-after-fetch, usage missing,
and midnight/month rollover before activation.

## Current official prices and credit suitability

Official model/pricing pages retrieved on 13 September 2026. Start the synthetic
comparison with `gpt-5.6-luna`; it supports Responses, Structured Outputs and
`none` reasoning. Its cost-sensitive positioning makes it a plausible candidate,
not a demonstrated quality winner. Compare `gpt-5.4-mini` if interpretation quality
warrants the extra cost. Verify account access and supported request parameters at
the time of an approved run.
[GPT-5.6 Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna),
[official pricing](https://developers.openai.com/api/docs/pricing)

Standard short-context, uncached planning example: 2,000 input and 400 total billed
output tokens per request (including reasoning where applicable).

| Model | Input / output per million, USD | Per request | 1,000 users × 4/month | 10,000 users × 4/month |
| --- | --- | --- | --- | --- |
| GPT-5.6 Luna | $0.20 / $1.20 | $0.00088 | $3.52 | $35.20 |
| GPT-5.4 mini | $0.75 / $4.50 | $0.00330 | $13.20 | $132.00 |

Formula: `(input × input_rate + billed_output × output_rate) / 1,000,000`.
Luna cache writes are $0.25/M, cached reads $0.02/M; the table assumes ordinary
uncached input, not a guarantee of actual token accounting. 50 users × four Luna
requests is about $0.176 at this example usage. 100 synthetic cases × three repeats
× both candidates is about $1.254 before retries/cache writes/backend costs/tax.
Those estimates come from the official rate table and arithmetic, not API trials.
[Official pricing](https://developers.openai.com/api/docs/pricing)

API credits could readily fund this bounded trial **if** they are usable in the
intended API project and unexpired. No balance, expiry, credit terms, project/model
access or billing configuration was inspected; available dollars cannot be
asserted. $1 of eligible credit covers about 1,136 example Luna requests or 303
mini requests before other costs. ChatGPT/Codex subscription limits/reset credits
are not API credit. Before any paid evaluation, verify the chosen API project,
usable balance/expiry, approved cap and no auto-recharge. If credits cannot cover
the approved bound, keep the local version; do not silently enable paid billing.

## Evaluation and abandonment gates

The checked-in [offline harness](../../scripts/personalisation-eval/evaluate.py)
contains no networking or credential access. Its 25 synthetic cases cover custom
and ambiguous goals, activity/motivation separation, shift work, caregivers,
nearby accessibility, communication needs, multilingual wording, sparse/conflicting
feedback, success, rejection, missing data, Brief Access and prompt injection.
Eight validator tests exercise wrong action/evidence, owner/consent/revision fences,
refusal/truncation, output limits, no eligible actions, and explicitly demonstrate
that valid schema can still contain a medical claim requiring rejection in review.

The local fallback has 25/25 structural passes and 20/25 acceptable mapping matches
on this small seed set. The five unmatched cases are opportunities to test clearer
mapping, **not proof that AI is better**; the shipped custom-preserving UX remains
valid. No model outputs, latency, actual token use or helpfulness scores exist yet.
The harness can score externally obtained authorised responses with `--responses`;
it deliberately cannot acquire them. Keep per-case failures visible.

Before a paid comparison, expand to 100 cases: use the 25 seed cases for development
and keep 75 unseen cases held out. Include negation, mixed goals, dialects,
malicious text inside notes, cross-account delayed replies, offline/key failures,
and budget concurrency. Use three repeats per candidate and shuffled blind review
by two reviewers. The scorecard must separately record:

- Critical privacy, owner, unsupported-action, invented-evidence, diagnostic or
  moralising failures: **zero**. Any such failure blocks the pilot, regardless of averages.
- Faithful interpretation ≥95%; acceptable unknown/custom handling ≥95%.
- At least 10 percentage points improvement over the appropriate local mapping
  task without increasing wrong classifications; do not count more classification as success.
- Relevant/useful offer ≥85%, with the user able to explain why it was offered;
  report disagreements and every invented-trend failure separately.
- Latency targets above and actual billed cost within reservation; record refusal,
  fallback and quota rates rather than treating them as successful outputs.

A later consenting four-week pilot compares local vs AI-assisted review and asks
whether an accepted change helped. Record acceptance, editing, dismissal burden
and later explicit helpfulness; no increase in reminder burden or compulsory
questions. App opens, timer minutes and reward counts are not measures of improved
habits. Synthetic evaluation cannot establish real-world benefit.

Abandon AI for this slice if it fails a critical gate, cannot outperform the local
baseline on held-out cases, makes people edit/correct more, has excessive latency,
requires extra sensitive data to work, or cannot enforce cost/retention boundaries.
After two bounded prompt iterations without useful improvement, stop spending and
retain the local product plus offline evaluation assets. No deployment or live
pilot is authorised by this document.
