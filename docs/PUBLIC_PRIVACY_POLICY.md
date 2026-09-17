# Counting Sheep App Privacy Policy

> **Source status — 2026-09-07:** The live policy published on 28 August 2026 remains at https://countingsheepproject.com/app-privacy-policy.html. This repository file is an unpublished candidate that separates the current baseline Slumber Party contract from additional gated behavior and fields. It is not evidence that a hosted migration, participant-data upload, beta, App Store build, or policy publication has occurred. Physical multi-account QA and retention operations remain separate gates.

**Effective date:** 28 August 2026

**Repository candidate updated:** 7 September 2026 — not published

Counting Sheep Project (“we”, “us”, or “Counting Sheep”) provides the Counting Sheep
iPhone and Apple Watch app. This policy explains how the app handles information. Counting
Sheep is a bedtime-habit and digital-wellbeing tool; it is not a medical device and does not
provide diagnosis or treatment. Its general sleep-health ideas are educational guidance, not
insomnia treatment, and this policy does not claim that qualified clinical review has occurred.

## Account-owned Farm sync — repository candidate, 7 September 2026

When you choose to use a Counting Sheep account, the app saves your Farm privately
in Supabase in Singapore, attached to your verified account. Farm synchronization is
automatic while you use that account. Existing users who previously declined or paused
uploads see a migration explanation before choosing to enable the new account behavior.
The backup includes sheep and their private names, owned/equipped cosmetics, wool,
capacity, Farm layout and appearance, search history and progress, welcome/social
reward claim records, and the aggregate completed Wind Down count needed for reward
continuity. It also includes Farm event dates and the accounting time intervals
needed to prevent the same elapsed time earning rewards twice.

This backup does not contain detailed Nights history, raw Health data, reflections,
questionnaire answers, routines, selected-app tokens, NFC credentials, social upload
queues or active timers. Farm inventory is not shared with Slumber Party members.
The account entrance explains automatic Farm sync before sign-in. Joining Slumber Party
still has its own sharing agreement; private Farm sync does not share your inventory.

Transfers use HTTPS and provider encryption at rest. Backups are not end-to-end
encrypted. Only a confirmed online save can be restored after device loss; offline
changes remain on the device until an upload succeeds. Conflicting Farms are kept
separately for the player to choose; balances are not added together.

The current copy remains until the account is deleted. Previous copies are retained
for 30 days, with at least the ten most recent resolved copies kept; unresolved
conflict copies remain until resolved or deleted. Older clients retain their separate
backup controls; generation checks block queued writes from recreating deleted copies.

Signing out closes the account’s Farm on this phone and removes its sign-in session.
An inaccessible recovery copy, including changes not yet uploaded, is kept on this
device for the same account’s next verified sign-in. Guest play and other accounts
cannot use it. This device-only recovery cannot survive loss of the phone. Account
deletion removes the account’s online Farm and its local recovery copies; local reset
also removes local recovery. These new-account semantics supersede the older baseline
statement below that a local Farm remains playable after account deletion.

Accounts support Apple sign-in or a verified email and password, with an optional
claimed username for login. Credentials resolve to the same immutable account ID when
linked. Supabase Auth verifies passwords; the app does not persist passwords. Username
login resolves the associated email only on the server, then asks Supabase Auth to
verify the password. It does not expose that lookup to unauthenticated clients. The
login endpoint uses keyed hashes of IP addresses and login identifiers for rate limits.
Confirmation, recovery and email-change codes are delivered through the configured mail
provider. Public deployment and provider configuration remain release gates.

## Information kept on your device

By default, Counting Sheep keeps the following information on your device:

- your Wind Down and Phone Away schedules, active session, and recent phone-away history;
- optional morning reflections and private routine suggestions;
- flock progress, legacy reward records, and app preferences;
- your Screen Time app/category selection, stored as Apple-provided opaque tokens;
- NFC phone-bed registration, stored as a one-way digest rather than the raw tag token;
- shield schedules and status evidence used to apply the protection you requested; and
- sleep summaries read from Apple Health, including sleep interval, duration, and available
  sleep stages.

Detailed behavioural history, Screen Time selections, NFC identity, free text, and raw
HealthKit samples are not sent to us by default.

## Apple Health

If you choose to connect Apple Health, Counting Sheep requests read access only to Sleep
Analysis. Depending on the source, this can include sleep start and end, time asleep,
awake periods, and core, deep, REM, or unspecified sleep stages. Counting Sheep does not
write to Apple Health.

Health information is used to show your own sleep context alongside your quiet-time
history. The separately gated Slumber Party candidate described below can share derived
sleep-duration summaries only when the service advertises the exact capability and you have
accepted that party's applicable agreement. The separate impact-sharing option has its own
agreement. We do not use Health information for advertising, sell it, provide it to data brokers,
or use it to make eligibility decisions. Missing Health data does not prevent joining a party or
change local rewards. Completing an Apple permission prompt does not let us determine whether
read access was granted; an empty result can mean no available records or unavailable access.

Counting Sheep does not diagnose or treat insomnia, prescribe a sleep schedule, or claim that
its guidance improves sleep. The full locally bundled source library is available in the app
through “About these ideas and sources.”

## Optional online services

Counting Sheep uses Supabase as a service provider. The app can create an anonymous
account identifier; you are not required to provide a name or email address.

When server-assisted Live Activity delivery is enabled, the service may process:

- an app installation identifier and anonymous user identifier;
- app version and Apple push environment;
- Wind Down run identifiers, planned transition times, state, and revision; and
- an ActivityKit push token and operational delivery results.

Push tokens are credentials used only to deliver the requested Live Activity update.
Backend delivery is optional support for the Lock Screen display; local Wind Down remains
authoritative.

## Optional impact sharing

If this option is available and you separately consent, Counting Sheep can share minimised
nightly measures so we can evaluate whether the ritual is helping people complete quiet
time and whether those changes are associated with sleep outcomes.

The shared record can include:

- a night number relative to when you consented, rather than a calendar date;
- planned and completed quiet minutes and whether the ritual completed;
- start-method and shielding-evidence categories;
- sleep duration and available core, deep, and REM minutes;
- an optional categorical restfulness answer; and
- app version.

The first upload can include up to 30 eligible nights before consent as a baseline. It does
not include exact dates or clock times, raw Health samples, Health source names, selected
apps, NFC identity, location, notification text, or personal free text.

You can stop future impact sharing in the app. You can also request deletion of shared
impact rows without deleting your detailed local history. We use this information only to
operate and evaluate Counting Sheep’s bedtime-habit service, not for advertising or
unrelated profiling. An observed association does not prove that Counting Sheep caused a
sleep outcome.

## Optional invite-only Slumber Party

Slumber Party is an optional, adult, private, invite-only feature. You can belong to up to five
long-lived groups. Each group is organized by fixed seven-night rounds; there is no shared goal or
readiness ceremony. Creating or joining requires Sign in with Apple. We do not request your Apple
name or email scope for this feature; Apple and Supabase process the provider identity and account
identifier used to authenticate membership.

### Current baseline contract

Before you create or join, the app discloses the baseline information visible to party members:

- your Shepherd display name, which people in every Slumber Party you join can see;
- your curated Shepherd appearance, Ollie ornament, featured sheep, and pasture theme;
- your membership, role, and participation in the current seven-night round;
- Wind Down or Phone Away entries shared during the round, including completion or early-ending
  state, rounded minutes, and the applicable round night; and
- brief session statuses and fixed cheers.

After the initial Shepherd-name choice, the service allows up to two successful name changes in
any rolling 14-day period. An unsuccessful attempt does not use one of those changes.

Wind Down and Phone Away entries and brief statuses originate as app records on the contributing
member's iPhone and are self-reported by the app to Slumber Party. Counting Sheep does not
independently verify them. A server receipt is not proof of sleep, physical phone placement,
continuously enforced app protection, or completion of a suggested routine. Wind Down minutes
describe the quiet period before bed, not hours asleep or overnight time.

The baseline party does not receive your full Farm inventory or wool, exact schedule or recurrence
rule, custom purpose, routine or reflection text, selected app identities, per-app use, Screen Time
tokens or reports, raw or derived Health data, NFC or phone-bed credentials, notification settings,
or impact-sharing data.

Invitation codes expire and are stored by the service in hashed form. Replacing or revoking an
invitation makes the old code stop working; current members remain in the party. Leaving stops new
updates and removes your access but does not dissolve the party for the other members. Only a host
can dissolve the party; dissolution closes its invitation and every member's access. Blocking
separates the two accounts across shared parties, removes mutual visibility, and prevents them from
joining a party together. Reporting sends the selected fixed reason to Counting Sheep; it does not
block the other member or promise a response, investigation, or moderation outcome. The service
keeps restricted blocking and reporting records needed to apply these controls; other party members
do not see those records.

Deleting your online Slumber Party account dissolves parties you host, leaves other parties, and
removes your Slumber Party contributions. Limited non-content security and deletion records may
remain where reasonably needed to prevent delayed retries, secure the service, or meet legal
obligations. Your local Wind Down and Farm records remain on your iPhone, and deleting social data
does not undo independently earned local rewards.

### Additional gated candidates

The repository contains an unpublished additive membership-sharing candidate that changes when
the already-disclosed baseline app activity, statuses, and cheers can appear. When a party advertises
the exact membership-sharing scope, a member can share those same categories after joining,
including before and between rounds. Practice stays excluded, existing private pre-join history is
not backfilled, and seven-night rounds still only organize progress and rewards. This activity-scope
change is capability-gated; it does not add the expanded fields below.

A separate unpublished candidate adds a chosen Shepherd, Ollie, or discovered-sheep social
identity, shared habit summaries, derived sleep duration, a retained party archive, and rounded
shared plans and nightly receipts. The app may present or publish each of these additional fields
only when the service advertises its exact supported capability and the member has accepted the
applicable agreement for that party. Existing members must accept an expanded agreement before
expanded fields are used for their contributions. There are no per-field switches inside an
accepted party agreement; withdrawing from that sharing means leaving the party. Joining does not
grant Apple Health or Screen Time permission, and adults can join without available Health data.

Depending on the exact capability and accepted agreement, additional party data can include:

- the member's explicitly chosen Shepherd, Ollie, or discovered-sheep identity and its curated
  appearance;
- app-recorded Wind Down and Phone Away summaries shared before, during, and between rounds;
- derived sleep duration for eligible completed nights, plus seven- and 30-night averages and the
  number of nights with available data;
- a plan rounded to five minutes for the next seven local nights: Wind Down timing, bedtime and
  wake bookends used for comparison, and ordered bundled routine-idea identifiers; and
- app-recorded nightly results with rounded start and terminal timing, outcome and minutes,
  available protection evidence, and emergency-exit status.

The same provenance limits apply to these records: Wind Down and Phone Away data is app-recorded on
the member's iPhone and self-reported to Slumber Party, not independently verified. Sleep duration
is derived only from an eligible Apple Health record. Missing data remains unknown rather than
zero, failure, or misconduct. Routine ideas describe a plan and are never proof of completion.
Protection evidence is not proof of physical placement or continuous device state.

The candidate does not share exact sleep intervals, stages, raw Health samples or Health source
names, recurrence rules, custom routine text, exact app identity, per-app use, Screen Time tokens,
NFC identity, full Farm inventory, wool, or impact-sharing data. Automatic sharing of exact app
usage or identity is not available through the current Singapore integration.

Under the candidate archive agreement, current and future members can see approved contributions
previously shared with the party, including earlier contributions from people who later leave.
Ordinary leaving stops new publication and removes access but does not erase earlier accepted
history. A separate deletion request can remove a former member's retained contributions; accepting
the agreement does not make them irrevocable. Dissolving the party removes its shared archive, and
deleting the online account removes that account's contributions. The service can retain limited
non-content agreement, security, and deletion markers needed to operate the controls safely.

This repository candidate is not a statement that backend migrations are deployed, an exact
capability is available, a member accepted an agreement, participant data is uploading, or the
candidate policy has been published.

## Optional feedback

The app includes a feedback form. If in-app delivery is enabled and you choose Send, we may
receive your selected category, message, optional reply email, and up to three screenshots
you specifically choose. The app re-encodes screenshots as JPEG to remove photo metadata and
reduce their size before upload.

An optional “Include technical details” control adds only the app version, build number,
iOS version, and device family. Feedback does not automatically attach logs, Apple Health
data, Screen Time selections, your schedule, NFC information, session identifiers, or a
persistent device identifier.

Supabase stores the feedback and private screenshot objects for us. Resend delivers a copy
to our support mailbox. We retain these feedback records and screenshots for up to 180 days;
the support mailbox follows the same retention period. If in-app delivery is disabled or
unavailable, you can use a prefilled message in your own Mail app instead.

## Service and device information

Our hosting providers can process ordinary network information such as IP address, request
time, and security logs when the app contacts the service. Apple separately processes
App Store, push-notification, HealthKit, Screen Time, and device information under Apple’s
own terms and privacy policies.

Counting Sheep does not contain third-party advertising SDKs and does not track you across
other companies’ apps or websites.

## Retention and deletion

Local ritual history is bounded in the app where stated and can also be removed by deleting
the app. Some system-managed Health and Screen Time information remains governed by your
Apple settings.

We retain backend operational information only as long as reasonably needed to provide,
secure, troubleshoot, and meet legal obligations for the service. Optional impact data is
deleted through the in-app deletion control after the service confirms the request. For Slumber
Party, in-app controls can remove eligible shared data or the full online account. For other backend
deletion or privacy requests, contact us using the details below. We may need
limited information to identify the anonymous installation involved.

## Security and service providers

We use technical and organisational safeguards intended to protect information, including
encrypted network transport, row-level access controls, and access limited to operating the
service. No method of storage or transmission can be guaranteed completely secure.

Supabase acts as our backend hosting and processing provider. Resend acts as our feedback
email delivery provider. Apple provides the operating
system services used by HealthKit, Screen Time, notifications, NFC, Nearby Interaction,
Watch connectivity, and Live Activities.

## Children and international use

Slumber Party is currently designed for adults. A group leader can organize the party but cannot
remotely control another adult's device protection. Counting Sheep is not listed in Apple’s Kids
category. If you believe a child has provided information to us, contact us.

Information may be processed in countries where our providers operate. Applicable
contractual and legal protections govern those transfers.

## Changes

We may update this policy when the app or its data practices change. We will update the
effective date and provide any notice required by law or platform rules. App Store privacy
disclosures will be kept consistent with the production app.

## Contact

Questions, deletion requests, or privacy concerns:

- Email: `countingsheep.sg@gmail.com`
- Website: `https://countingsheepproject.com/`
