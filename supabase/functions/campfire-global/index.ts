import { authenticatedContext, serviceClient } from "../_shared/supabase.ts";
import { handleGlobalCampfire } from "../_shared/global-campfire-handler.ts";
import { globalCampfireSharedText, moderateSharedText, sharedTextModerationEnvironment } from "../_shared/shared-text-moderation.ts";

Deno.serve(request => handleGlobalCampfire(request, {
  async authenticate(candidate) {
    const { user } = await authenticatedContext(candidate);
    return { id: user.id, isAnonymous: user.is_anonymous === true };
  },
  async moderate(candidate, owner, body) {
    await moderateSharedText(candidate, owner, "campfire-global", String(body.id ?? ""),
      globalCampfireSharedText(body), {
        ...sharedTextModerationEnvironment(),
        async admit(signal) {
          const { error } = await serviceClient().rpc("shared_text_moderation_admission", { p_user_id: owner }).abortSignal(signal);
          if (error) throw error;
        },
      });
  },
  async execute(owner, body) {
    const admin = serviceClient();
    return body.command === "state"
      ? await admin.rpc("global_campfire_state", { p_user_id: owner, p_gathering: body.gathering ?? "all", p_cursor: body.cursor ?? null, p_channel: body.channelID ?? null })
      : body.command === "detail"
      ? await admin.rpc("global_campfire_detail", { p_user_id: owner, p_participant_id: body.participantID ?? null, p_member_id: body.memberID ?? null })
      : await admin.rpc("global_campfire_command", { p_user_id: owner, p_command: body });
  },
}));
