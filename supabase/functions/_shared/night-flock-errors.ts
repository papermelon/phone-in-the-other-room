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
  | "internal_error";

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
  active_membership_exists: "You already have an active Slumber Party.",
  alias_conflict: "Ollie couldn’t choose a unique alias for this lobby.",
  invite_member_constraint: "That invitation could not be added. Please try again.",
  active_invite_exists: "This lobby already has an active invitation.",
  current_membership_required: "Your Slumber Party membership could not be found.",
  invite_unavailable: "That invitation is no longer available.",
  lobby_started: "That lobby has already started.",
  flock_full: "That Slumber Party is full.",
  blocked_membership: "This Slumber Party is unavailable for this account.",
  host_permission_required: "Only the host can do that.",
  account_unavailable: "Slumber Party is unavailable for this account.",
  snapshot_construction_failed: "Slumber Party could not load your lobby. Please try again.",
  service_unavailable: "Slumber Party is resting offline. Please try again.",
  internal_error: "Slumber Party could not complete that request.",
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
  if (detail.includes("night_flock_members_one_active_flock_per_user") || detail.includes("night_flock_members_one_active_record_per_flock")) return nightFlockError("active_membership_exists");
  if (detail.includes("23505") && (detail.includes("night_flock_members_active_alias") || detail.includes("alias"))) return nightFlockError("alias_conflict");
  if (detail.includes("night_flock_members_active_alias")) return nightFlockError("alias_conflict");
  if (detail.includes("23505") && (detail.includes("invite") || detail.includes("member"))) return nightFlockError("invite_member_constraint");
  if (detail.includes("a reusable invitation already exists") || detail.includes("active_invite_exists")) return nightFlockError("active_invite_exists");
  if (detail.includes("snapshot") || detail.includes("projection") || detail.includes("construct") && detail.includes("state")) return nightFlockError("snapshot_construction_failed");
  if (detail.includes("current membership required")) return nightFlockError("current_membership_required");
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
