import { json, parseJsonObject } from "./http.ts";
import { validateGlobalCampfire, validatesCampfireOwner } from "./global-campfire.ts";
import { SharedTextModerationError } from "./shared-text-moderation.ts";
import { classifyNightFlockError } from "./night-flock-errors.ts";

export type GlobalCampfireDependencies = {
  authenticate(request: Request): Promise<{ id: string; isAnonymous: boolean }>;
  moderate(request: Request, owner: string, body: Record<string, unknown>): Promise<void>;
  execute(owner: string, body: Record<string, unknown>): Promise<{ data: unknown; error: { message: string } | null }>;
};

export async function handleGlobalCampfire(request: Request, dependencies: GlobalCampfireDependencies): Promise<Response> {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const user = await dependencies.authenticate(request);
    if (user.isAnonymous) return json({ error: "Unauthorized" }, 401);
    const body = validateGlobalCampfire(await parseJsonObject(request));
    if (!["state", "detail"].includes(String(body.command)) && !validatesCampfireOwner(request.headers.get("X-Campfire-Owner"), user.id)) {
      return json({ error: "Account changed. Reopen Campfire before retrying." }, 409);
    }
    await dependencies.moderate(request, user.id, body);
    const { data, error } = await dependencies.execute(user.id, body);
    if (error) {
      if (["agreement_required", "immutable_session", "session_unavailable", "profile_unavailable", "invalid_session", "invalid_profile", "invalid_channel"].includes(error.message)) {
        return json({ accepted: false, retryable: false });
      }
      return json({ error: "Campfire request wasn’t accepted. Refresh and review visibility." }, 400);
    }
    return json(body.command === "state" ? { accepted: true, state: data } : data);
  } catch (error) {
    if (error instanceof SharedTextModerationError) {
      const { status, ...body } = classifyNightFlockError(error);
      return json(body, status);
    }
    return json({ error: error instanceof Error && error.message === "Unauthorized" ? "Unauthorized" : "Invalid Campfire request" },
      error instanceof Error && error.message === "Unauthorized" ? 401 : 400);
  }
}
