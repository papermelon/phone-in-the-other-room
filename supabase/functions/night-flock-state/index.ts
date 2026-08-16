import { handleNightFlockState } from "../_shared/night-flock-handlers.ts";
import { authenticatedClient, serviceClient } from "../_shared/supabase.ts";

Deno.serve((request) => handleNightFlockState(request, {
  async authenticate(candidate) {
    const client = await authenticatedClient(candidate);
    const { data, error } = await client.auth.getUser();
    if (error || !data.user) throw new Error("Unauthorized");
    return { id: data.user.id, isAnonymous: data.user.is_anonymous === true };
  },
  async read(callerID, schemaVersion) {
    const { data, error } = await serviceClient().rpc(schemaVersion === 2
      ? "night_flock_commitment_state"
      : "night_flock_state", {
      p_user_id: callerID,
    });
    if (error) throw error;
    return data;
  },
}));
