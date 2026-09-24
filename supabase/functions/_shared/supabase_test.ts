import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { authenticatedContext } from "./supabase.ts";

Deno.test("authentication verifies once and returns the verified user; rejection stays closed", async () => {
  Deno.env.set("SUPABASE_URL", "https://auth-fixture.invalid");
  Deno.env.set("SUPABASE_ANON_KEY", "test-public-key");
  const original = globalThis.fetch;
  let calls = 0;
  let accepted = true;
  globalThis.fetch = async () => {
    calls++;
    return new Response(JSON.stringify(accepted
      ? { id: "10000000-0000-4000-8000-000000000001", is_anonymous: false, aud: "authenticated" }
      : { msg: "Invalid token" }), { status: accepted ? 200 : 401, headers: { "content-type": "application/json" } });
  };
  try {
    const request = new Request("https://fixture.invalid", { headers: { Authorization: "Bearer fixture" } });
    const { user } = await authenticatedContext(request);
    assertEquals(calls, 1);
    assertEquals(user.id, "10000000-0000-4000-8000-000000000001");
    assertEquals(user.is_anonymous, false);
    accepted = false;
    await assertRejects(() => authenticatedContext(request), Error, "Unauthorized");
    await assertRejects(() => authenticatedContext(new Request("https://fixture.invalid")), Error, "Unauthorized");
    assertEquals(calls, 2);
  } finally {
    globalThis.fetch = original;
    Deno.env.delete("SUPABASE_URL");
    Deno.env.delete("SUPABASE_ANON_KEY");
  }
});
