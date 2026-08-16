import { handleNightFlockCommand } from "../_shared/night-flock-handlers.ts";
import { authenticatedClient, serviceClient } from "../_shared/supabase.ts";

Deno.serve((request) => handleNightFlockCommand(request, {
  async authenticate(candidate) {
    const client = await authenticatedClient(candidate);
    const { data, error } = await client.auth.getUser();
    if (error || !data.user) throw new Error("Unauthorized");
    return { id: data.user.id, isAnonymous: data.user.is_anonymous === true };
  },
  async execute(callerID, payload) {
    const admin = serviceClient();
    const { data, error } = await admin.rpc(payload.schemaVersion === 2
      ? "night_flock_commitment_command"
      : "night_flock_command", {
      p_user_id: callerID,
      p_command: payload,
    });
    if (error) throw error;
    if (!data || typeof data !== "object") throw new Error("Slumber Party result unavailable");
    return data as {
      accepted: boolean;
      inviteCode?: string | null;
      inviteID?: string | null;
      deleteAccount?: boolean;
      snapshot?: unknown;
    };
  },
  async deleteAccount(callerID) {
    const { error } = await serviceClient().auth.admin.deleteUser(callerID, false);
    if (error) throw error;
  },
}));
