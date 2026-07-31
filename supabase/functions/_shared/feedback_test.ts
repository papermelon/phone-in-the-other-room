import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { deliverNextFeedback } from "./feedback-delivery.ts";
import { validateFeedbackPayload } from "./feedback.ts";

const userID = "10000000-0000-4000-8000-000000000001";
const submissionID = "50000000-0000-4000-8000-000000000001";

Deno.test("feedback payload accepts zero through three owned JPEG paths", () => {
  for (const count of [0, 1, 3]) {
    const paths = Array.from(
      { length: count },
      (_, index) => `${userID}/${submissionID}/attachment-${index + 1}.jpg`,
    );
    const result = validateFeedbackPayload({
      schemaVersion: 1,
      submissionID,
      category: "general",
      message: "A clear piece of feedback.",
      replyEmail: null,
      diagnostics: null,
      attachmentPaths: paths,
    }, userID);
    assertEquals(result.attachmentPaths, paths);
  }
});

Deno.test("feedback payload rejects malformed fields and foreign paths", () => {
  const valid = {
    schemaVersion: 1,
    submissionID,
    category: "bug",
    message: "The action did not work.",
    replyEmail: null,
    diagnostics: null,
    attachmentPaths: [],
  };
  assertThrows(
    () => validateFeedbackPayload({ ...valid, message: "short" }, userID),
    Error,
    "10 to 4000",
  );
  assertThrows(
    () => validateFeedbackPayload({ ...valid, category: "shop" }, userID),
    Error,
    "Invalid category",
  );
  assertThrows(
    () =>
      validateFeedbackPayload({ ...valid, replyEmail: "not-an-email" }, userID),
    Error,
    "Invalid replyEmail",
  );
  assertThrows(
    () =>
      validateFeedbackPayload({
        ...valid,
        attachmentPaths: [
          `20000000-0000-4000-8000-000000000001/${submissionID}/attachment-1.jpg`,
        ],
      }, userID),
    Error,
    "Invalid attachment path",
  );
});

Deno.test("delivery uses the feedback UUID for Resend and records failure for retry", async () => {
  const originalFetch = globalThis.fetch;
  const originalValues = new Map<string, string | undefined>();
  for (
    const [name, value] of [
      ["RESEND_API_KEY", "test-key"],
      ["FEEDBACK_FROM_EMAIL", "Ollie <feedback@example.com>"],
      ["FEEDBACK_TO_EMAIL", "support@example.com"],
    ]
  ) {
    originalValues.set(name, Deno.env.get(name));
    Deno.env.set(name, value);
  }

  const finishes: Record<string, unknown>[] = [];
  const client = {
    rpc(name: string, args: Record<string, unknown>) {
      if (name === "claim_feedback_delivery") {
        return Promise.resolve({ data: [feedbackRow()], error: null });
      }
      finishes.push(args);
      return Promise.resolve({ data: null, error: null });
    },
  } as unknown as SupabaseClient;

  try {
    globalThis.fetch = (_input, init) => {
      assertEquals(
        new Headers(init?.headers).get("idempotency-key"),
        submissionID,
      );
      return Promise.resolve(
        new Response("provider unavailable", { status: 503 }),
      );
    };
    assertEquals(await deliverNextFeedback(client, submissionID), "failed");
    assertEquals(finishes.length, 1);
    assertEquals(finishes[0].p_id, submissionID);
    assertEquals(finishes[0].p_succeeded, false);
    assertEquals(
      String(finishes[0].p_error).includes("Resend 503"),
      true,
    );

    globalThis.fetch = () => Promise.reject(new Error("network offline"));
    await assertRejects(
      async () => {
        const brokenClient = {
          rpc(name: string) {
            if (name === "claim_feedback_delivery") {
              return Promise.reject(new Error("database offline"));
            }
            return Promise.resolve({ data: null, error: null });
          },
        } as unknown as SupabaseClient;
        await deliverNextFeedback(brokenClient, submissionID);
      },
      Error,
      "database offline",
    );
  } finally {
    globalThis.fetch = originalFetch;
    for (const [name, value] of originalValues) {
      if (value === undefined) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
});

function feedbackRow() {
  return {
    id: submissionID,
    category: "bug",
    message: "The button did not respond.",
    reply_email: null,
    diagnostics_included: true,
    app_version: "1.0",
    app_build: "1",
    ios_version: "iOS 19.0",
    device_family: "iPhone",
    attachment_paths: [],
    created_at: "2026-08-01T00:00:00Z",
  };
}
