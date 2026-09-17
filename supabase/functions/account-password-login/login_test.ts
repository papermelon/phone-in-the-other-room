import { assertEquals } from "jsr:@std/assert@1";
import {
  type AccountPasswordLoginDependencies,
  accountPasswordLoginHandler,
} from "./login.ts";

function dependencies(
  overrides: Partial<AccountPasswordLoginDependencies> = {},
): AccountPasswordLoginDependencies {
  return {
    service: () => ({
      rpc: async (name) => {
        if (name === "account_password_login_rate_limit_v1") {
          return {
            data: true,
            error: null,
          };
        }
        return { data: "shepherd@example.test", error: null };
      },
    }),
    password: () => ({
      auth: {
        signInWithPassword: async () => ({
          data: {
            session: {
              access_token: "token",
              refresh_token: "refresh",
              token_type: "bearer",
              expires_in: 3600,
            },
          },
          error: null,
        }),
      },
    }),
    rateLimitSecret: () => "unit-test-secret",
    requireCaptcha: () => false,
    clientIP: () => "203.0.113.9",
    limits: () => ({ ip: 20, identifier: 5, windowSeconds: 300 }),
    ...overrides,
  };
}

function request(body: unknown): Request {
  return new Request("https://example.test/account-password-login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("username password login returns the normal Auth session body", async () => {
  const response = await accountPasswordLoginHandler(dependencies())(
    request({ username: "@Shepherd_1", password: "correct horse" }),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    access_token: "token",
    refresh_token: "refresh",
    token_type: "bearer",
    expires_in: 3600,
  });
});

Deno.test("missing username and wrong password have the same public response", async () => {
  const wrongPassword = accountPasswordLoginHandler(
    dependencies({
      password: () => ({
        auth: {
          signInWithPassword: async () => ({
            data: { session: null },
            error: new Error("bad password"),
          }),
        },
      }),
    }),
  );
  const missingUsername = accountPasswordLoginHandler(dependencies({
    service: () => ({
      rpc: async (name) =>
        name === "account_password_login_rate_limit_v1"
          ? { data: true, error: null }
          : { data: null, error: null },
    }),
    password: () => ({
      auth: {
        signInWithPassword: async () => ({
          data: { session: null },
          error: new Error("bad password"),
        }),
      },
    }),
  }));
  const [wrong, missing] = await Promise.all([
    wrongPassword(request({ username: "shepherd_1", password: "wrong" })),
    missingUsername(request({ username: "missing_1", password: "wrong" })),
  ]);
  assertEquals(wrong.status, 401);
  assertEquals(await wrong.text(), await missing.text());
});

Deno.test("a fallback address can never authenticate an absent username", async () => {
  const handler = accountPasswordLoginHandler(dependencies({
    service: () => ({
      rpc: async (name) =>
        name === "account_password_login_rate_limit_v1"
          ? { data: true, error: null }
          : { data: null, error: null },
    }),
    password: () => ({
      auth: {
        signInWithPassword: async () => ({
          data: { session: { access_token: "must-not-return" } },
          error: null,
        }),
      },
    }),
  }));
  const response = await handler(
    request({ username: "missing_1", password: "correct-password" }),
  );
  assertEquals(response.status, 401);
  assertEquals(await response.json(), {
    error: "Invalid username or password",
  });
});

Deno.test("rate limiting blocks before username lookup or Auth", async () => {
  let called = false;
  const response = await accountPasswordLoginHandler(dependencies({
    service: () => ({ rpc: async () => ({ data: false, error: null }) }),
    password: () => ({
      auth: {
        signInWithPassword: async () => {
          called = true;
          return { data: { session: null }, error: null };
        },
      },
    }),
  }))(request({ username: "shepherd_1", password: "wrong" }));
  assertEquals(response.status, 429);
  assertEquals(called, false);
});

Deno.test("malformed usernames consume the same rate-limit gate as wrong passwords", async () => {
  let attempts = 0;
  const handler = accountPasswordLoginHandler(
    dependencies({
      service: () => ({
        rpc: async (name) => {
          if (name === "account_password_login_rate_limit_v1") {
            return { data: ++attempts < 3, error: null };
          }
          return { data: null, error: null };
        },
      }),
      password: () => ({
        auth: {
          signInWithPassword: async () => ({
            data: { session: null },
            error: new Error("bad password"),
          }),
        },
      }),
    }),
  );
  assertEquals(
    (await handler(request({ username: "bad name", password: "wrong" })))
      .status,
    401,
  );
  assertEquals(
    (await handler(request({ username: "shepherd_1", password: "wrong" })))
      .status,
    401,
  );
  assertEquals(
    (await handler(request({ username: "bad name", password: "wrong" })))
      .status,
    429,
  );
  assertEquals(attempts, 3);
});

Deno.test("configured captcha is required and forwarded to Auth", async () => {
  let captcha: string | undefined;
  const handler = accountPasswordLoginHandler(
    dependencies({
      requireCaptcha: () => true,
      password: () => ({
        auth: {
          signInWithPassword: async (credentials) => {
            captcha = credentials.options?.captchaToken;
            return {
              data: { session: { access_token: "token" } },
              error: null,
            };
          },
        },
      }),
    }),
  );
  assertEquals(
    (await handler(request({ username: "shepherd_1", password: "password" })))
      .status,
    400,
  );
  assertEquals(
    (await handler(
      request({
        username: "shepherd_1",
        password: "password",
        captchaToken: "challenge",
      }),
    )).status,
    200,
  );
  assertEquals(captcha, "challenge");
});
