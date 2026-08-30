export type NightFlockErrorCode =
  | "unauthorized"
  | "linked_account_required"
  | "method_not_allowed"
  | "invalid_request"
  | "unsupported_schema"
  | "active_membership_exists"
  | "alias_conflict"
  | "invite_member_constraint"
  | "active_invite_exists"
  | "current_membership_required"
  | "invite_unavailable"
  | "lobby_started"
  | "flock_full"
  | "blocked_membership"
  | "host_permission_required"
  | "account_unavailable"
  | "snapshot_construction_failed"
  | "service_unavailable"
  | "internal_error"
  | "max_parties"
  | "host_cannot_leave"
  | "stale_revision"
  | "name_change_limit"
  | "client_upgrade_required"
  | "shared_history_deleted"
  | "publication_before_agreement"
  | "agreement_timezone_mismatch"
  | "publication_outside_plan_window"
  | "publication_outside_receipt_window"
  | "invalid_shared_night_payload"
  | "invalid_plan_chronology"
  | "invalid_receipt_chronology"
  | "invalid_plan_binding"
  | "invalid_receipt_source"
  | "receipt_plan_mismatch"
  | "shared_night_plan_frozen"
  | "shared_night_plan_cancelled"
  | "receipt_actual_start_required";

export type NightFlockRecovery = "reconcileMembership" | "reconcile" | "retry" | "fallbackSchema" | "linkAccount" | "authenticate" | null;

export type NightFlockErrorDescriptor = {
  status: number;
  code: NightFlockErrorCode;
  error: string;
  retryable: boolean;
  recovery: NightFlockRecovery;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const safeMessages: Record<NightFlockErrorCode, string> = {
  unauthorized: "Unauthorized",
  linked_account_required: "Linked account required",
  method_not_allowed: "Method not allowed",
  invalid_request: "Invalid request",
  unsupported_schema: "Unsupported schema",
  active_membership_exists: "You already belong to this Slumber Party.",
  alias_conflict: "Ollie couldn’t choose a unique name for this Slumber Party.",
  invite_member_constraint: "That invitation could not be added. Please try again.",
  active_invite_exists: "This Slumber Party already has an active invitation.",
  current_membership_required: "Your Slumber Party membership could not be found.",
  invite_unavailable: "That invitation is no longer available.",
  lobby_started: "That Slumber Party is no longer accepting invitations.",
  flock_full: "That Slumber Party is full.",
  blocked_membership: "This Slumber Party is unavailable for this account.",
  host_permission_required: "Only the host can do that.",
  account_unavailable: "Slumber Party is unavailable for this account.",
  snapshot_construction_failed: "This Slumber Party could not open. Please try again.",
  service_unavailable: "Slumber Party is resting offline. Please try again.",
  internal_error: "Slumber Party could not complete that request.",
  max_parties: "You can be in up to five Slumber Parties.",
  host_cannot_leave: "Delete this Slumber Party before leaving.",
  stale_revision: "That change is out of date. Please refresh your Slumber Party.",
  name_change_limit: "You can change your display name twice every 14 days.",
  client_upgrade_required: "Update Counting Sheep to use multiple Slumber Parties.",
  shared_history_deleted: "That shared history was deleted and will not be sent again.",
  publication_before_agreement: "That update was recorded before this party agreement.",
  agreement_timezone_mismatch: "That sleep summary belongs to a different agreement time zone.",
  publication_outside_plan_window: "That plan is outside this party’s next-seven-night window.",
  publication_outside_receipt_window: "That nightly result is outside this party’s current window.",
  invalid_shared_night_payload: "That shared-night update could not be used.",
  invalid_plan_chronology: "That shared plan’s timing did not fit its night.",
  invalid_receipt_chronology: "That nightly result’s timing did not fit its night.",
  invalid_plan_binding: "That nightly result no longer matches its saved plan.",
  invalid_receipt_source: "That nightly result needs its saved night identity.",
  receipt_plan_mismatch: "That nightly result no longer matches its saved plan.",
  shared_night_plan_frozen: "That shared plan has already begun and will stay as it was.",
  shared_night_plan_cancelled: "That shared night is no longer available and will not be sent.",
  receipt_actual_start_required: "That factual nightly result needs its recorded start time.",
};

export function requestIDFor(value: string | null | undefined): string {
  const candidate = value?.trim() ?? "";
  return uuidPattern.test(candidate) ? candidate.toLowerCase() : crypto.randomUUID().toLowerCase();
}

export function nightFlockError(code: NightFlockErrorCode): NightFlockErrorDescriptor {
  switch (code) {
    case "unauthorized": return { status: 401, code, error: safeMessages[code], retryable: false, recovery: "authenticate" };
    case "linked_account_required": return { status: 403, code, error: safeMessages[code], retryable: false, recovery: "linkAccount" };
    case "blocked_membership":
    case "account_unavailable":
      return { status: 403, code, error: safeMessages[code], retryable: false, recovery: null };
    case "method_not_allowed": return { status: 405, code, error: safeMessages[code], retryable: false, recovery: null };
    case "unsupported_schema": return { status: 400, code, error: safeMessages[code], retryable: false, recovery: "fallbackSchema" };
    case "active_membership_exists": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcileMembership" };
    case "max_parties": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcileMembership" };
    case "host_cannot_leave": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "stale_revision": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "name_change_limit": return { status: 429, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "client_upgrade_required": return { status: 426, code, error: safeMessages[code], retryable: false, recovery: "fallbackSchema" };
    case "shared_history_deleted": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "publication_before_agreement": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "agreement_timezone_mismatch": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "publication_outside_plan_window":
    case "publication_outside_receipt_window":
    case "invalid_shared_night_payload":
    case "invalid_plan_chronology":
    case "invalid_receipt_chronology":
    case "invalid_plan_binding":
    case "invalid_receipt_source":
    case "receipt_plan_mismatch": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "shared_night_plan_frozen": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "shared_night_plan_cancelled": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "receipt_actual_start_required": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "alias_conflict": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: null };
    case "invite_member_constraint": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "active_invite_exists": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "current_membership_required": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcileMembership" };
    case "invite_unavailable": return { status: 410, code, error: safeMessages[code], retryable: false, recovery: null };
    case "lobby_started": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "flock_full": return { status: 409, code, error: safeMessages[code], retryable: false, recovery: null };
    case "host_permission_required": return { status: 403, code, error: safeMessages[code], retryable: false, recovery: "reconcile" };
    case "snapshot_construction_failed": return { status: 500, code, error: safeMessages[code], retryable: true, recovery: "retry" };
    case "service_unavailable": return { status: 503, code, error: safeMessages[code], retryable: true, recovery: "retry" };
    case "invalid_request": return { status: 400, code, error: safeMessages[code], retryable: false, recovery: null };
    case "internal_error": return { status: 500, code, error: safeMessages[code], retryable: true, recovery: "retry" };
  }
}

export function classifyNightFlockError(error: unknown): NightFlockErrorDescriptor {
  const detail = safeClassificationDetail(error);
  if (detail.includes("unauthorized") || detail.includes("invalid jwt")) return nightFlockError("unauthorized");
  if (detail.includes("apple-linked account") || detail.includes("linked account required")) return nightFlockError("linked_account_required");
  if (detail.includes("one active slumber party")) return nightFlockError("active_membership_exists");
  if (detail.includes("max_parties")) return nightFlockError("max_parties");
  if (detail.includes("host_cannot_leave")) return nightFlockError("host_cannot_leave");
  if (detail.includes("stale_revision")) return nightFlockError("stale_revision");
  if (detail.includes("shared_history_deleted")) return nightFlockError("shared_history_deleted");
  if (detail.includes("publication_before_agreement")) return nightFlockError("publication_before_agreement");
  if (detail.includes("agreement_timezone_mismatch")) return nightFlockError("agreement_timezone_mismatch");
  if (detail.includes("publication_outside_plan_window")) return nightFlockError("publication_outside_plan_window");
  if (detail.includes("publication_outside_receipt_window")) return nightFlockError("publication_outside_receipt_window");
  if (detail.includes("invalid_shared_night_payload")) return nightFlockError("invalid_shared_night_payload");
  if (detail.includes("invalid_plan_chronology")) return nightFlockError("invalid_plan_chronology");
  if (detail.includes("invalid_receipt_chronology")) return nightFlockError("invalid_receipt_chronology");
  if (detail.includes("invalid_plan_binding")) return nightFlockError("invalid_plan_binding");
  if (detail.includes("invalid_receipt_source")) return nightFlockError("invalid_receipt_source");
  if (detail.includes("receipt_plan_mismatch")) return nightFlockError("receipt_plan_mismatch");
  if (detail.includes("shared_night_plan_frozen")) return nightFlockError("shared_night_plan_frozen");
  if (detail.includes("shared_night_plan_cancelled")) return nightFlockError("shared_night_plan_cancelled");
  if (detail.includes("receipt_actual_start_required")) return nightFlockError("receipt_actual_start_required");
  if (detail.includes("name_change_limit")) return nightFlockError("name_change_limit");
  if (detail.includes("client_upgrade_required")) return nightFlockError("client_upgrade_required");
  if (detail.includes("night_flock_members_one_active_flock_per_user") || detail.includes("night_flock_members_one_active_record_per_flock")) return nightFlockError("active_membership_exists");
  if (detail.includes("23505") && (detail.includes("night_flock_members_active_alias") || detail.includes("alias"))) return nightFlockError("alias_conflict");
  if (detail.includes("night_flock_members_active_alias")) return nightFlockError("alias_conflict");
  if (detail.includes("23505") && (detail.includes("invite") || detail.includes("member"))) return nightFlockError("invite_member_constraint");
  if (detail.includes("a reusable invitation already exists") || detail.includes("active_invite_exists")) return nightFlockError("active_invite_exists");
  if (detail.includes("snapshot") || detail.includes("projection") || detail.includes("construct") && detail.includes("state")) return nightFlockError("snapshot_construction_failed");
  if (detail.includes("current membership required") || detail.includes("current_membership_required")) return nightFlockError("current_membership_required");
  if (detail.includes("unsupported schem")) return nightFlockError("unsupported_schema");
  if (detail.includes("account already joined this lobby")) return nightFlockError("active_membership_exists");
  if (detail.includes("invite") && (detail.includes("expired") || detail.includes("revoked") || detail.includes("used") || detail.includes("unavailable") || detail.includes("replay") || detail.includes("invalid"))) return nightFlockError("invite_unavailable");
  if (detail.includes("lobby") && (detail.includes("started") || detail.includes("closed") || detail.includes("unavailable"))) return nightFlockError("lobby_started");
  if (detail.includes("challenge unavailable") || detail.includes("invitations close") || detail.includes("lobby unavailable")) return nightFlockError("lobby_started");
  if (detail.includes("full") || detail.includes("capacity")) return nightFlockError("flock_full");
  if (detail.includes("blocked membership") || detail.includes("blocked")) return nightFlockError("blocked_membership");
  if (detail.includes("host") && (detail.includes("permission") || detail.includes("required"))) return nightFlockError("host_permission_required");
  if (detail.includes("unavailable for this account")) return nightFlockError("account_unavailable");
  if (detail.includes("alias pool unavailable")) return nightFlockError("service_unavailable");
  if (detail.includes("service unavailable") || detail.includes("temporarily") || detail.includes("timeout") || detail.includes("fetch failed") || detail.includes("relay")) return nightFlockError("service_unavailable");
  if (detail.includes("invalid") || detail.includes("missing") || detail.includes("unexpected") || detail.includes("unsupported") || detail.includes("mismatch")) return nightFlockError("invalid_request");
  return nightFlockError("internal_error");
}

export function safeNightFlockError(error: unknown): NightFlockErrorDescriptor {
  return classifyNightFlockError(error);
}

function safeClassificationDetail(error: unknown): string {
  if (error instanceof Error) {
    const candidate = error as Error & { code?: unknown; details?: unknown; hint?: unknown };
    return [candidate.code, candidate.message, candidate.details, candidate.hint]
      .filter((value): value is string => typeof value === "string")
      .join(" ")
      .toLowerCase();
  }
  if (!error || typeof error !== "object") return "";
  const candidate = error as Record<string, unknown>;
  return [candidate.code, candidate.message, candidate.details, candidate.hint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();
}
