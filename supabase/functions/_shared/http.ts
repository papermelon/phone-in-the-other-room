export const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

export function errorResponse(error: unknown): Response {
  const message = error instanceof Error ? error.message : "Unexpected error";
  const status = message === "Unauthorized" ? 401 : 400;
  return json({ error: message }, status);
}

export async function parseJsonObject(
  request: Request,
): Promise<Record<string, unknown>> {
  const body = await request.json();
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Invalid JSON body");
  }
  return body as Record<string, unknown>;
}

export function requireString(
  body: Record<string, unknown>,
  key: string,
): string {
  const value = body[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Missing ${key}`);
  }
  return value;
}
