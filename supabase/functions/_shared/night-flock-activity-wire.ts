// FunctionInvokeOptions uses Foundation's default JSONEncoder in shipped apps:
// Date is seconds since 2001-01-01, whereas PostgreSQL expects an ISO timestamp.
// Normalize only the agreed v4 activity/status timestamps before validation and
// idempotency hashing. ISO clients retain their original payload unchanged.
export function normalizeActivityTimestamp(value: unknown, field: string): string {
  if (typeof value === "string") return value;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`Invalid ${field}`);
  }
  const milliseconds = value * 1000 + Date.UTC(2001, 0, 1);
  const date = new Date(milliseconds);
  if (!Number.isFinite(date.getTime())) throw new Error(`Invalid ${field}`);
  return date.toISOString();
}
