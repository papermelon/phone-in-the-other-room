import { handleNightFlockState } from "../_shared/night-flock-handlers.ts";
import { authenticatedContext, serviceClient } from "../_shared/supabase.ts";

Deno.serve((request) => handleNightFlockState(request, {
  async authenticate(candidate) {
    const { user } = await authenticatedContext(candidate);
    return { id: user.id, isAnonymous: user.is_anonymous === true };
  },
  async read(callerID, contract) {
    const { data, error, status } = await serviceClient().rpc(
      contract.schemaVersion === 4
        ? "night_flock_v4_state"
        : contract.schemaVersion === 3
        ? "night_flock_social_state"
        : contract.schemaVersion === 2
        ? "night_flock_commitment_state"
        : "night_flock_state",
      {
      ...(contract.schemaVersion === 4
        ? { p_user_id: callerID, p_scope: contract.scope, p_party_id: contract.partyID ?? null, p_cursor: contract.cursor ?? null }
        : { p_user_id: callerID }),
    });
    if (error) throw Object.assign(error, { status });
    return data;
  },
}));
