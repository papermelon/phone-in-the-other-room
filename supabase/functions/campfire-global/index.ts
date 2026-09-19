import { authenticatedClient, serviceClient } from "../_shared/supabase.ts";
import { json, parseJsonObject } from "../_shared/http.ts";
import { validateGlobalCampfire, validatesCampfireOwner } from "../_shared/global-campfire.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const auth = await authenticatedClient(request);
    const { data: { user } } = await auth.auth.getUser();
    if (!user || user.is_anonymous) return json({ error: "Unauthorized" }, 401);
    const body = validateGlobalCampfire(await parseJsonObject(request));
    if (body.command !== "state" && !validatesCampfireOwner(request.headers.get("X-Campfire-Owner"), user.id)) {
      return json({ error: "Account changed. Reopen Campfire before retrying." }, 409);
    }
    const admin = serviceClient();
    const { data, error } = body.command === "state"
      ? await admin.rpc("global_campfire_state", { p_user_id: user.id, p_gathering: body.gathering ?? "all", p_cursor: body.cursor ?? null })
      : await admin.rpc("global_campfire_command", { p_user_id: user.id, p_command: body });
    if (error) {
      if (["agreement_required", "immutable_session", "session_unavailable", "profile_unavailable", "invalid_session"].includes(error.message)) {
        return json({ accepted: false, retryable: false });
      }
      return json({ error: "Campfire request wasn’t accepted. Refresh and review visibility." }, 400);
    }
    return json(body.command === "state" ? { accepted: true, state: data } : data);
  } catch (error) {
    return json({ error: error instanceof Error && error.message === "Unauthorized" ? "Unauthorized" : "Invalid Campfire request" },
      error instanceof Error && error.message === "Unauthorized" ? 401 : 400);
  }
});
