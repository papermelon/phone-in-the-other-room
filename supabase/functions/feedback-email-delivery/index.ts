import { json } from "../_shared/http.ts";
import {
  deliverNextFeedback,
  purgeExpiredFeedback,
} from "../_shared/feedback-delivery.ts";
import { serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  const expectedSecret = Deno.env.get("FEEDBACK_DELIVERY_SECRET");
  if (
    !expectedSecret ||
    request.headers.get("x-feedback-delivery-secret") !== expectedSecret
  ) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const admin = serviceClient();
    const { data, error } = await admin.rpc("feedback_delivery_candidate_ids");
    if (error) throw error;

    let delivered = 0;
    let failed = 0;
    for (const row of data ?? []) {
      const result = await deliverNextFeedback(admin, row.id);
      if (result === "delivered") delivered += 1;
      if (result === "failed") failed += 1;
    }
    const purged = await purgeExpiredFeedback(admin);
    return json({ attempted: (data ?? []).length, delivered, failed, purged });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    return json({ error: message }, 500);
  }
});
