import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

type FeedbackRow = {
  id: string;
  category: "bug" | "featureRequest" | "general";
  message: string;
  reply_email: string | null;
  diagnostics_included: boolean;
  app_version: string | null;
  app_build: string | null;
  ios_version: string | null;
  device_family: string | null;
  attachment_paths: string[];
  created_at: string;
};

type ResendAttachment = {
  filename: string;
  content: string;
};

const attachmentBucket = "feedback-attachments";

export async function deliverNextFeedback(
  client: SupabaseClient,
  requestedID: string | null = null,
): Promise<"delivered" | "failed" | "empty"> {
  const { data, error } = await client.rpc("claim_feedback_delivery", {
    p_id: requestedID,
  });
  if (error) throw error;
  const feedback = (data?.[0] ?? null) as FeedbackRow | null;
  if (!feedback) return "empty";

  try {
    const attachments = await loadAttachments(
      client,
      feedback.attachment_paths,
    );
    await sendResendEmail(feedback, attachments);
    await finishDelivery(client, feedback.id, true, null);
    return "delivered";
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Unexpected delivery error";
    await finishDelivery(client, feedback.id, false, message);
    return "failed";
  }
}

export async function purgeExpiredFeedback(
  client: SupabaseClient,
  now = new Date(),
): Promise<number> {
  const { data: orphaned, error: orphanError } = await client.rpc(
    "expired_feedback_attachment_paths",
  );
  if (orphanError) throw orphanError;
  const orphanedPaths = (orphaned ?? []).map(
    (row: { path: string }) => row.path,
  );
  if (orphanedPaths.length > 0) {
    const { error: orphanStorageError } = await client.storage
      .from(attachmentBucket)
      .remove(orphanedPaths);
    if (orphanStorageError) throw orphanStorageError;
  }

  const cutoff = new Date(now.getTime() - 180 * 24 * 60 * 60 * 1000)
    .toISOString();
  const { data, error } = await client
    .from("app_feedback")
    .select("id, attachment_paths")
    .lt("created_at", cutoff)
    .limit(100);
  if (error) throw error;
  if (!data || data.length === 0) return orphanedPaths.length;

  const paths = data.flatMap((row) => row.attachment_paths as string[]);
  if (paths.length > 0) {
    const { error: storageError } = await client.storage
      .from(attachmentBucket)
      .remove(paths);
    if (storageError) throw storageError;
  }

  const ids = data.map((row) => row.id as string);
  const { error: deleteError } = await client.from("app_feedback").delete().in(
    "id",
    ids,
  );
  if (deleteError) throw deleteError;
  return ids.length + orphanedPaths.length;
}

async function loadAttachments(
  client: SupabaseClient,
  paths: string[],
): Promise<ResendAttachment[]> {
  const result: ResendAttachment[] = [];
  for (const [index, path] of paths.entries()) {
    const { data, error } = await client.storage.from(attachmentBucket)
      .download(path);
    if (error) throw error;
    result.push({
      filename: `screenshot-${index + 1}.jpg`,
      content: bytesToBase64(new Uint8Array(await data.arrayBuffer())),
    });
  }
  return result;
}

async function sendResendEmail(
  feedback: FeedbackRow,
  attachments: ResendAttachment[],
): Promise<void> {
  const apiKey = requiredEnvironment("RESEND_API_KEY");
  const from = requiredEnvironment("FEEDBACK_FROM_EMAIL");
  const to = requiredEnvironment("FEEDBACK_TO_EMAIL");
  const category = categoryTitle(feedback.category);
  const diagnostics = feedback.diagnostics_included
    ? [
      `App: ${feedback.app_version ?? "Unknown"} (${
        feedback.app_build ?? "Unknown"
      })`,
      `iOS: ${feedback.ios_version ?? "Unknown"}`,
      `Device: ${feedback.device_family ?? "Unknown"}`,
    ].join("\n")
    : "Not included";
  const text = [
    `Counting Sheep feedback: ${category}`,
    `Feedback ID: ${feedback.id}`,
    `Received: ${feedback.created_at}`,
    "",
    feedback.message,
    "",
    "Technical details",
    diagnostics,
  ].join("\n");

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
      "idempotency-key": feedback.id,
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: `[Counting Sheep feedback] ${category}`,
      text,
      reply_to: feedback.reply_email ?? undefined,
      attachments,
    }),
  });
  if (!response.ok) {
    const details = (await response.text()).slice(0, 500);
    throw new Error(`Resend ${response.status}: ${details}`);
  }
}

async function finishDelivery(
  client: SupabaseClient,
  id: string,
  succeeded: boolean,
  error: string | null,
): Promise<void> {
  const { error: databaseError } = await client.rpc(
    "finish_feedback_delivery",
    {
      p_id: id,
      p_succeeded: succeeded,
      p_error: error,
    },
  );
  if (databaseError) throw databaseError;
}

function categoryTitle(category: FeedbackRow["category"]): string {
  if (category === "featureRequest") return "Feature idea";
  if (category === "bug") return "Bug";
  return "General";
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Server configuration missing ${name}`);
  return value;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(
      ...bytes.subarray(offset, offset + chunkSize),
    );
  }
  return btoa(binary);
}
