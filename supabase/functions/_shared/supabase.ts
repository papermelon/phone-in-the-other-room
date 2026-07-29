import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Server configuration missing ${name}`);
  return value;
}

export async function authenticatedClient(
  request: Request,
): Promise<SupabaseClient> {
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) throw new Error("Unauthorized");

  const client = createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    },
  );
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new Error("Unauthorized");
  return client;
}

export function serviceClient(): SupabaseClient {
  return createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false } },
  );
}
