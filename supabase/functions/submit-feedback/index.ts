import { errorResponse, json, parseJsonObject } from "../_shared/http.ts";
import { deliverNextFeedback } from "../_shared/feedback-delivery.ts";
import { validateFeedbackPayload } from "../_shared/feedback.ts";
import { authenticatedClient, serviceClient } from "../_shared/supabase.ts";

const attachmentBucket = "feedback-attachments";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const userClient = await authenticatedClient(request);
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    if (userError || !userData.user) throw new Error("Unauthorized");

    const body = await parseJsonObject(request);
    const feedback = validateFeedbackPayload(body, userData.user.id);
    const idempotencyKey = request.headers.get("idempotency-key")
      ?.toLowerCase();
    if (idempotencyKey !== feedback.submissionID) {
      throw new Error("Idempotency key mismatch");
    }

    const admin = serviceClient();
    await verifyAttachments(
      admin,
      userData.user.id,
      feedback.submissionID,
      feedback.attachmentPaths,
    );

    const diagnostics = feedback.diagnostics;
    const { data, error: insertError } = await admin.rpc(
      "submit_app_feedback",
      {
        p_id: feedback.submissionID,
        p_user_id: userData.user.id,
        p_category: feedback.category,
        p_message: feedback.message,
        p_reply_email: feedback.replyEmail,
        p_diagnostics_included: diagnostics !== null,
        p_app_version: diagnostics?.appVersion ?? null,
        p_app_build: diagnostics?.buildNumber ?? null,
        p_ios_version: diagnostics?.operatingSystem ?? null,
        p_device_family: diagnostics?.deviceFamily ?? null,
        p_attachment_paths: feedback.attachmentPaths,
      },
    );
    if (insertError) throw insertError;
    const inserted = data?.[0];
    if (!inserted) throw new Error("Feedback receipt unavailable");

    // Notification failure is recorded for retry and never discards the accepted report.
    try {
      await deliverNextFeedback(admin, inserted.feedback_id);
    } catch (deliveryError) {
      console.error(
        "Initial feedback notification could not be claimed",
        deliveryError,
      );
    }
    return json(
      { id: inserted.feedback_id, acceptedAt: inserted.accepted_at },
      202,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (message.toLowerCase().includes("feedback limit reached")) {
      return json(
        {
          error:
            "Feedback limit reached. Please try again tomorrow or use email.",
        },
        429,
      );
    }
    return errorResponse(error);
  }
});

async function verifyAttachments(
  admin: ReturnType<typeof serviceClient>,
  userID: string,
  submissionID: string,
  paths: string[],
): Promise<void> {
  if (paths.length === 0) return;
  const prefix = `${userID.toLowerCase()}/${submissionID}`;
  const { data, error } = await admin.storage.from(attachmentBucket).list(
    prefix,
    {
      limit: 3,
      sortBy: { column: "name", order: "asc" },
    },
  );
  if (error) throw error;
  const storedPaths = (data ?? []).map((item) => `${prefix}/${item.name}`);
  if (
    storedPaths.length !== paths.length ||
    storedPaths.some((path, index) => path !== paths[index])
  ) {
    throw new Error("One or more attachments are unavailable");
  }
}
