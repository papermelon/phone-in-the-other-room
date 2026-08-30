# Singapore/SEA verified app sharing — feasibility gate

2026-08-28. **Finding: no supported customer-distribution path established for the requested Singapore feature.** Documentation/SDK inspection only; no entitlement change, runtime probe, Apple inquiry, deployment or participant-data upload performed.

## Required result

Adults in an invite-only Slumber Party agree to share their habit information. The product must
automatically identify the exact apps selected for shielding, group those identities into useful
categories, and present app usage/protection information accurately to other consenting members.
Singapore and Southeast Asia are the primary audience. The founder rejected manually chosen
category descriptions as an accountability substitute. Region-specific adapters may follow later;
an EU-only implementation does not satisfy this initial requirement.

## Evidence checked

| Route | Documented capability | Does it establish the requested Singapore route? |
| --- | --- | --- |
| Current Family Controls selection + Managed Settings | Opaque selections authorize local protection. System views/extensions can present identities in their permitted contexts. | No established exportable app-identity-to-selection mapping for this adult social use case. A token or label displayed locally is not a server-verifiable name. |
| DeviceActivityReport | Renders usage inside a report extension; Apple documents a sandbox preventing network calls and movement of sensitive content outside that extension. | No. A private report displayed on the owner's phone is not a remotely shared social metric. |
| FamilyActivityData / approvedWithDataAccess | Explicitly authorized non-tokenized identities, separate usage entitlement and EU customer location/account requirements. | No for the stated market. Development/testing eligibility outside the EU is not customer eligibility. |
| DeviceActivityData.activityData(filteredBy:using:) | Documented export method for activity data, subject to the same EU customer and entitlement conditions. | No Singapore customer route under the published conditions. |
| Counting Sheep session/protection history | Local session times and apply/clear/failure events. | Useful evidence for its own events, but does not identify apps or measure their usage. Not an accepted replacement for the exact-app requirement. |

Primary references: [DeviceActivityReport](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport),
[FamilyActivityData](https://developer.apple.com/documentation/familycontrols/familyactivitydata),
[export method](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitydata(filteredby:using:)),
[data-access authorization](https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess),
[usage entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls.app-and-website-usage).

The installed iPhoneOS 26.5 SDK independently declares the identity and export APIs above as
available from **iOS 26.4**. Read-only checks used `xcrun --sdk iphoneos --show-sdk-path` and the
FamilyControls/DeviceActivity `arm64e-apple-ios.swiftinterface` files. The app's current deployment
target is iOS 17. No runtime success is inferred from the symbols being present.

### Verification is not a single Boolean

Prove separately: identity of a selected app; its category mapping/version; OS-reported usage for
a defined time window; protection applied to the relevant selection; continuity/known gaps; and
the server's confidence in the client's submission. A successful session or a server-received
payload does not prove all six. If an allowed identity route is found, retain the private
selection-to-identity provenance and avoid claiming unrelated installed apps were shielded.

Do not bypass the report or shield sandbox through OCR, hidden view extraction, App Group
exfiltration, logs, private APIs or region/account spoofing. Do not relabel adults as children
to obtain family-only access. VPN, device-management or research entitlements are not substitutes
without their own applicable public API, intended-use and distribution proof; none is proposed
as a workaround here.

## Next bounded technical task — Terra High, Sol acceptance

1. Ask Apple Developer Technical Support whether an authorized public route exists for this
   exact adult Singapore social use case. The draft below is **not sent**; external submission
   needs approval and may require the account holder. Check entitlement/distribution requirements,
   not just whether a development build can resolve a bundle identifier.
2. If Apple identifies an applicable route, make a separately approved minimal probe. Verify
   signed customer/TestFlight behavior on a Singapore device/account, iOS support, app identity,
   selection mapping, usage scope, revocation and two-account delivery. Use explicit test consent,
   no background extraction of the founder's private app data. No target/signing/entitlement
   changes without approval.
3. Return **supported with evidence**, **documented unsupported**, or **unresolved awaiting Apple**.
   A fixture, local-only report, screenshot, manual declaration or EU developer result cannot pass.
4. Until a permitted path is demonstrated, the requested verified social app breakdown is blocked.
   Other independent UI/guide work may proceed if authorized, but do not describe it as completing
   the accountability feature. A platform/market/scope change belongs to the founder.

### Unsent Apple inquiry draft

> We develop Counting Sheep, an iPhone bedtime-habit app for adults, primarily in Singapore and
> Southeast Asia. Users authorize individual Family Controls, select apps for shielding, and may
> explicitly agree to share habit summaries with a small invite-only group. We need to identify
> selected apps automatically, categorize them and share per-app usage and protection summaries.
> We understand that DeviceActivityReport and shield-configuration extensions are sandboxed, and
> the newer FamilyActivityData / activityData export route has EU customer restrictions. Is there
> a supported public API or entitlement for this consented non-EU use case? If so, what are the
> OS, regional, account, purpose and App Store/TestFlight distribution requirements? Does it expose
> a verifiable mapping from the selected opaque apps to their identities, and permit the described
> sharing? We do not seek to bypass the extension sandbox or change an adult into a child account.

## Join agreement, permission and withdrawal

The founder selected one clear sharing agreement at joining, followed by sharing on for that
party and leaving to withdraw. Implementing that preference still requires an accessible exit,
respect for system permissions, and a necessary/limited data purpose. Apple requires consent,
withdrawal and respect for permission choices; Singapore's PDPC also distinguishes what is
reasonably needed for a service and requires withdrawal to be honored. The product choice alone
does not establish compliance. Review the mandatory data bundle before shipping, especially any
requirement to authorize HealthKit or any reward/paid-access dependency.
[Apple privacy rules](https://developer.apple.com/app-store/review/guidelines/#privacy),
[PDPC obligations](https://www.pdpc.gov.sg/overview-of-pdpa/the-legislation/personal-data-protection-act/data-protection-obligations).

The founder approved joining without Health data: share available authorized data under the
agreement and show “No data available” where absent. Never infer cheating or denial from an empty
Health read. Provide contextual native connection actions, with truthful observed-data status;
see [connection repair](contextual-connections-health-status.md). No per-field party switches or
forced OS permission. Joining and creating both need the agreement; new fields and expanded
historical audiences require contributor re-consent, not retroactive consent by a new reader.

Leaving immediately stops this device's publication, removes pending sends and the leaver's
group cache, then revokes remote access on reconnect. Mark remote completion pending offline.
Leader approval or successful transfer cannot block leaving; preserve local sessions, Farm and
earned independent rewards.

The founder wants later members to see all previous group history, including former-member
contributions, and ordinary leaving to preserve that history. Record this as the intended archive
contract, not an irrevocable permission. Continued access is continued disclosure: a prior join
clause alone does not settle withdrawal of consent under the PDPA or Apple deletion requirements.
Validate retained sensitive-data disclosure, archive duration and existing-contributor migration
before rollout. Distinguish ordinary leave from accessible privacy withdrawal/deletion and account
deletion, available without rejoining. No field-toggle matrix is needed for those rights.
[PDPC withdrawal obligations](https://www.pdpc.gov.sg/overview-of-pdpa/the-legislation/personal-data-protection-act/data-protection-obligations),
[Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app).

The founder selected archive retention for the lifetime of the party, subject to legitimate
deletion requests and the review above. Seven/thirty-night summaries are not retention limits.
Do not silently truncate history to those windows or promise retention after dissolution. Expired legacy
records and private pre-join Health history are not automatically restored or imported.
