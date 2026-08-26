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
  | "client_upgrade_required";

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
