import { handleNightFlockCommand } from "../_shared/night-flock-handlers.ts";
import { createInvitation, decryptInvitation, invitationKeyForVersion, invitationKeyFromEnvironment, redactInvitationResult } from "../_shared/night-flock-invites.ts";
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
    const { data, error } = await admin.rpc(
      payload.schemaVersion === 4
        ? "night_flock_v4_command"
        : payload.schemaVersion === 3
        ? "night_flock_social_command"
        : payload.schemaVersion === 2
        ? "night_flock_commitment_command"
        : "night_flock_command",
      {
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
  async prepare(payload) {
    if (payload.schemaVersion !== 4 || !["createInvite", "replaceInvite", "retrieveInvite"].includes(payload.command)) {
      return { payload, transform: async (result) => result };
    }
    if (payload.command === "retrieveInvite") {
      return {
        payload,
        transform: async (result) => {
          const envelope = result.inviteEnvelope as { inviteCiphertext: string; inviteNonce: string; inviteKeyVersion: number } | undefined;
          if (!envelope) throw new Error("Invite unavailable");
          const material = invitationKeyForVersion(envelope.inviteKeyVersion);
          return { ...redactInvitationResult(result), inviteCode: await decryptInvitation(envelope, material.key) } as typeof result;
        },
      };
    }
    const material = invitationKeyFromEnvironment();
    const invitation = await createInvitation(material.key, material.version);
    const internalPayload = {
      ...payload,
      inviteDigest: invitation.digest,
      ...invitation.envelope,
    };
    return {
      payload: internalPayload,
      transform: async (result) => {
        const envelope = result.inviteEnvelope as { inviteCiphertext: string; inviteNonce: string; inviteKeyVersion: number } | undefined;
        if (!envelope) throw new Error("Invite unavailable");
        const storedMaterial = invitationKeyForVersion(envelope.inviteKeyVersion);
        return { ...redactInvitationResult(result), inviteCode: await decryptInvitation(envelope, storedMaterial.key) } as typeof result;
      },
    };
  },
  async deleteAccount(callerID) {
    const { error } = await serviceClient().auth.admin.deleteUser(callerID, false);
    if (error) throw error;
  },
}));
