# Slumber Party consent, invitations and feedback — 21 September 2026

Founder request: consolidate fragmented agreements, repair creation and invitation feedback,
correct icon alignment, replace code-first joining with searchable invitations, and animate waits.

## Current direction

- One **Terms of agreement** disclosure contains baseline sharing, shared-habit additions,
  capability-gated rounded plans, evidence limits, private fields and leaving/history consequences.
  Create/join is the affirmative action. No additional data is consented merely by expanding it.
- Successful creation/join closes the acquisition form and opens the exact accepted party once
  its membership list arrives. A membership acknowledgement and Open party action remain while
  a list refresh is pending. Agreement confirmation is a distinct, server-receipt-backed state at the top
  of the party. Pending/error states stay visible and permit agreement retry.
- **Invite people** uses an exact existing account handle or immutable user UUID. Results expose
  only the matched account's display name/handle/ID and its member/invited state. No email search,
  public party directory, partial-name enumeration or social-history preview is introduced.
- The handle is the existing account username. Email registration includes claiming it after
  verification; existing Apple accounts can choose one in Sign-in and username. Every verified
  account already has an immutable UUID, including accounts that have not chosen a username.
- Current members can send invitations; only the addressed recipient accepts or declines.
  The sender or host may revoke while still a member. Invitations expire after seven days;
  a declined invitation cannot be immediately resent within that original window. Acceptance
  rechecks current sender membership, blocks, party existence and both capacity limits.
- Code exchange remains in a secondary disclosure for compatibility. Its cached credential is
  bound to the specific party and current invitation ID. Code retrieval does not depend on an
  unrelated list refresh; progress/failure stays beside the invitation controls.
- Bramble's existing running art supplies indeterminate waiting feedback in Slumber Party,
  Campfire, account and other existing network waits. Reduce Motion and inactive scenes pause it.
  VoiceOver reads the operation and “In progress,” not animation frames.
  The [loading follow-up](wind-down-loading-repair-2026-09-21.md) adds a clearer hop/dot rhythm and bounded Campfire reads.
- Shared chip buttons have horizontal padding, including the Campfire entry icon.

## Source and backend boundary

`20260921120000_slumber_party_invitations.sql` adds a private addressed-invitation table and
`slumber_party_connections_v1`. The authenticated RPC derives its caller from `auth.uid()`;
clients cannot supply a caller. The table has RLS and no client table access. Lookup is bounded
and rate-limited; state is filtered to incoming invitations and authorized party members.
Terminal/expired rows are removed after 30 days on participants' subsequent requests.
Acceptance creates membership but does not fabricate a shared-habits consent receipt. The app
uses the existing staged, command-bound agreement outbox and confirmation endpoint.

`directInvitationsVersion: 1` in the existing list contract gates new controls. Older servers omit
it and retain the code fallback. Existing invitation encryption secrets and v4 endpoints remain
in place; this migration does not rotate or replace credentials.

Creation and code-join retries retain their command key during an uncertain response in the
current app session. Duplicate taps are ignored while an acquisition is in flight. The existing
durable agreement intent binds to the server's exact resolved party; no party is guessed from a
list difference. Closing/relaunching during an uncertain create still needs canonical-list
reconciliation before deciding to create again; the new in-memory retry state is not a new
persistent command queue.

## Design references

Reviewed Mobbin's [X invitation result](https://mobbin.com/screens/ab548435-ff5f-475e-8a70-130bc4915c79)
(search with visible Invited status), [Teams invite selection](https://mobbin.com/screens/c792ea22-6b7e-4408-8da1-7753d5914c98)
and [Nike Run Club pending invitation](https://mobbin.com/screens/0d827773-5cc1-4bc6-8c0f-aa91c90b8af4).
The app retains Counting Sheep's typography, colors and native controls.

## Validation and release state

See [local evidence](../../output/design/slumber-party-repair-20260921/README.md).
The invitation backend was [deployed with explicit founder authorization](../evidence/slumber-invitation-deploy-20260921/deployment.md)
on 21 September. Hosted migration, account-handle and invitation checks passed with rolled-back
synthetic fixtures. No real invitation was sent or real party modified. TestFlight distribution
and two-account physical validation remain separate and outstanding. The original screenshot's
request ID cannot establish a current hosted failure cause without production request logs.
