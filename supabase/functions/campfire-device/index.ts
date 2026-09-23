import { authenticatedContext, serviceClient } from "../_shared/supabase.ts";
import { errorResponse, json, parseJsonObject } from "../_shared/http.ts";
import { validateCampfireDevice } from "../_shared/campfire-alerts.ts";

Deno.serve(async request => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const { user } = await authenticatedContext(request);
    if (!user || user.is_anonymous) return json({ error: "Unauthorized" }, 401);
    const body = await parseJsonObject(request);
    validateCampfireDevice(body, user.id);
    const admin = serviceClient();
    const { error } = body.unregister === true
      ? await admin.rpc("unregister_campfire_device", { p_user_id: user.id, p_installation_id: body.installationID, p_revision: body.revision })
      : await admin.rpc("register_campfire_device", {
        p_user_id: user.id, p_installation_id: body.installationID, p_token: body.token,
        p_environment: body.environment, p_enabled: body.enabled, p_quiet_until: body.quietUntil,
        p_time_zone: body.timeZone, p_quiet_start: body.quietStart, p_quiet_end: body.quietEnd, p_revision: body.revision,
      });
    if (error) throw error;
    return json({ accepted: true });
  } catch (error) { return errorResponse(error); }
});
