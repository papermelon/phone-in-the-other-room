# Counting Sheep App Privacy Policy

> **Publication record — 2026-08-28:** The live policy was published with founder approval at https://countingsheepproject.com/app-privacy-policy.html. The version-2 Slumber Party plan/receipt language below describes a repository-local candidate behind additive capability and agreement gates; it is not evidence that the hosted migration or any v2 participant-data upload is deployed. Physical two-account QA and retention operations remain separate gates.

**Effective date:** 28 August 2026

Counting Sheep Project (“we”, “us”, or “Counting Sheep”) provides the Counting Sheep
iPhone and Apple Watch app. This policy explains how the app handles information. Counting
Sheep is a bedtime-habit and digital-wellbeing tool; it is not a medical device and does not
provide diagnosis or treatment. Its general sleep-health ideas are educational guidance, not
insomnia treatment, and this policy does not claim that qualified clinical review has occurred.

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
history. If you also agree to Slumber Party sharing, derived sleep-duration summaries can be
shared with your parties as described below. The separate impact-sharing option has its own
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

Slumber Party is an optional, adult, invite-only shared habit feature. You can belong to up to
five parties. Activity sharing starts with membership; seven-night rounds organize group progress
and rewards rather than requiring you to wait before sharing. Creating or joining requires
Sign in with Apple. We do not request your Apple name or email scope for this feature; Apple and
Supabase process the provider identity and account identifier used to authenticate membership.

Before creating or joining each party, you see and accept its sharing agreement. Existing members
must accept the expanded agreement before the new sleep summaries or lifetime archive are used
for their contributions. There are no separate switches for each shared field. Joining does not
grant Apple Health or Screen Time permission, and you can join without available Health data.

Under the agreement, the party can receive:

- your chosen display name and one chosen character with its selected appearance;
- membership, role, round participation, brief session statuses, and fixed cheers;
- factual Wind Down or Phone Away duration and completion information, with a local day where
  known; Wind Down summaries use the quiet period before bed, not hours asleep or overnight time;
- app-recorded protection duration where evidence is available, which is not proof of physical
  phone placement or a continuously verified device state; and
- derived sleep duration for eligible completed nights, with weekly and monthly averages and
  the number of nights with available data, when Apple Health provides records.
- in the repository-local, separately gated version-2 candidate only: a rounded plan for the next seven local nights: Wind
  Down timing, bedtime and wake bookends used for factual comparison, ordered bundled routine
  idea identifiers, and factual nightly results. Routine ideas describe a plan, not verified
  completion; unavailable evidence remains unknown.

Sleep summaries do not include exact sleep intervals, stages, raw samples, or Health source
names. The version-2 plan does not include your recurrence rule or custom routine text. NFC identity,
Screen Time tokens, selected app identities, per-app use, full Farm inventory, wool, and impact-sharing
data are not shared with the party. Automatic sharing of exact app usage or app identities is not available through
the current Singapore integration. We do not present unavailable data as zero usage or a failed habit.

The service also stores agreement version and acceptance time, contributor timezone, private
source references for updating or deleting records, hashed expiring invitations, and restricted
blocking, reporting, and moderation records. These operational fields are not all shown to peers.

Current and future members can see contributions previously shared under this agreement.
Ordinary leaving stops new publication to that party and removes your access, but those approved
past contributions remain for the lifetime of the party, attributed as former-member history.
Existing private pre-join records are not automatically uploaded. Previously group-shared coarse
activity can be retained under the expanded agreement without adding private detail.

You can leave, block, report, or request deletion of your shared contributions. A separate
deletion or withdrawal request removes your contributions even after you leave; accepting the
agreement does not make them irrevocable. Deleting the online account removes its contributions.
Dissolving a party removes its shared archive. Limited non-content deletion markers can remain to
prevent delayed retries from restoring deleted contributions. Local ritual and Farm records do
not require the social service to work, and deleting shared history does not undo independently
earned local rewards.

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
deleted through the in-app deletion control after the service confirms the request. For Night
Flock, in-app controls can remove Slumber Party data or the full online account. For other backend
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
