type JsonObject = Record<string, unknown>;

export type NightFlockLocalDateWire = {
  year: number;
  month: number;
  day: number;
};

/**
 * Build 36 encodes NightFlockLocalDate as Codable's keyed object, while the
 * shared-habits SQL contract uses canonical calendar-day strings. Keep that
 * compatibility conversion at the Edge boundary so the RPC and its
 * idempotency comparison continue to receive one representation.
 */
export function normalizeSharedHabitsLocalDate(value: unknown): string {
  if (typeof value === "string") {
    if (!isCalendarDay(value)) throw new Error("Invalid localDate");
    return value;
  }
  if (!isJsonObject(value) || Array.isArray(value)) throw new Error("Invalid localDate");
  const keys = Object.keys(value).sort();
  if (keys.length !== 3 || keys[0] !== "day" || keys[1] !== "month" || keys[2] !== "year") {
    throw new Error("Invalid localDate");
  }
  const { year, month, day } = value;
  if (![year, month, day].every(Number.isSafeInteger)) throw new Error("Invalid localDate");
  const canonical = `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  if (!isCalendarDay(canonical)) throw new Error("Invalid localDate");
  return canonical;
}

export function adaptSharedHabitsStateWire(snapshot: unknown): unknown {
  if (!isJsonObject(snapshot) || Array.isArray(snapshot)) {
    throw new Error("Shared habits state unavailable");
  }
  const adapted = { ...snapshot };
  if (adapted.agreement !== null && adapted.agreement !== undefined) {
    adapted.agreement = adaptDateField(adapted.agreement, "firstEligibleSleepNight");
  }
  adapted.records = adaptDateFields(adapted.records, ["localDate", "activityDate"]);
  adapted.periods = adaptDateFields(adapted.periods, ["endingOn"]);
  if (Array.isArray(adapted.sharedNightPlans)) adapted.sharedNightPlans = adaptDateFields(adapted.sharedNightPlans, ["nightEndingDate"]);
  if (Array.isArray(adapted.sharedNightReceipts)) adapted.sharedNightReceipts = adaptDateFields(adapted.sharedNightReceipts, ["nightEndingDate"]);
  return adapted;
}

function adaptDateFields(value: unknown, fields: string[]): JsonObject[] {
  if (!Array.isArray(value)) throw new Error("Shared habits state unavailable");
  return value.map((item) => fields.reduce<JsonObject>(
    (adapted, field) => adaptDateField(adapted, field),
    requireObject(item),
  ));
}

function adaptDateField(value: unknown, field: string): JsonObject {
  const object = requireObject(value);
  if (!(field in object) || object[field] === null) return { ...object };
  return { ...object, [field]: dateObjectFromCanonical(object[field]) };
}

function dateObjectFromCanonical(value: unknown): NightFlockLocalDateWire {
  const canonical = normalizeSharedHabitsLocalDate(value);
  const [year, month, day] = canonical.split("-").map(Number);
  return { year, month, day };
}

function isCalendarDay(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (year < 1) return false;
  const instant = new Date(Date.UTC(year, month - 1, day));
  return instant.getUTCFullYear() === year && instant.getUTCMonth() === month - 1 && instant.getUTCDate() === day;
}

function isJsonObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null;
}

function requireObject(value: unknown): JsonObject {
  if (!isJsonObject(value) || Array.isArray(value)) throw new Error("Shared habits state unavailable");
  return value;
}
