// Only text explicitly submitted to a social audience belongs in this module.
export const sharedTextConsentVersion = "1";
export type SharedTextErrorCode = "shared_text_consent_required" | "shared_text_review_required" |
  "shared_text_rejected" | "shared_text_unavailable" | "shared_text_too_large";

export class SharedTextModerationError extends Error {
  code: SharedTextErrorCode;
  reviewToken?: string;
  constructor(code: SharedTextErrorCode, reviewToken?: string) {
    super(code); this.code = code; this.reviewToken = reviewToken;
  }
}

type Category = "hate" | "hate/threatening" | "harassment" | "harassment/threatening";
const thresholds: Record<Category, { review: number; reject: number }> = {
  hate: { review: 0.5, reject: 0.95 },
  "hate/threatening": { review: 0.4, reject: 0.85 },
  harassment: { review: 0.6, reject: 0.97 },
  "harassment/threatening": { review: 0.4, reject: 0.85 },
};

// Scores are model signals, not calibrated probabilities. These conservative
// launch thresholds need language/false-positive evaluation before activation.
export function sharedTextDecision(result: unknown): "allow" | "review" | "reject" {
  if (!result || typeof result !== "object") throw new SharedTextModerationError("shared_text_unavailable");
  const scores = (result as Record<string, unknown>).category_scores as Record<string, unknown> | undefined;
  let review = false;
  let reject = false;
  for (const [category, limits] of Object.entries(thresholds)) {
    const score = scores?.[category];
    if (typeof score !== "number" || !Number.isFinite(score) || score < 0 || score > 1) {
      throw new SharedTextModerationError("shared_text_unavailable");
    }
    if (score >= limits.reject) reject = true;
    if (score >= limits.review) review = true;
  }
  // Overall `flagged`, profanity, sexual/violence/self-harm classifications do
  // not decide this narrowly scoped hate/targeted-harassment policy.
  return reject ? "reject" : review ? "review" : "allow";
}

function text(values: unknown[]): string[] {
  return [...new Set(values.filter((v): v is string => typeof v === "string")
    .map(v => v.trim()).filter(Boolean))];
}

export function nightFlockSharedText(c: Record<string, unknown>): string[] {
  if (c.schemaVersion !== 4) return c.command === "createParty" ? text([c.appDisplayName]) : [];
  switch (c.command) {
    case "createParty": case "renameParty": return text([c.name]);
    case "updatePublicProfile": return text([c.displayName]);
    case "campfireBuddyAction": return c.buddyAction === "reflect" ? text([c.reflection]) : [];
    case "publishCampfireSession": return c.ended === false ? text([c.publicIntention]) : [];
    default: return [];
  }
}

export function globalCampfireSharedText(c: Record<string, unknown>): string[] {
  if (c.command === "agreement" && c.enabled === true && c.consentVersion === 2) return text([c.publicName]);
  if (c.command !== "profile") return [];
  const p = c.profile as Record<string, unknown>;
  // Unknown inventory IDs are displayed verbatim by the profile's fallback.
  return text([
    ...["session", "tasks", "routines", "history", "partyNames", "inventory"].flatMap(k => p[k] as unknown[]),
    p.intention,
    ...(p.sheep as Record<string, unknown>[]).map(s => s.name),
  ]);
}

export type SharedTextModerationOptions = {
  enabled: boolean;
  apiKey?: string;
  fetch?: typeof fetch;
  admit?: (signal: AbortSignal) => Promise<void>;
};

async function reviewToken(owner: string, scope: string, commandID: string, texts: string[]): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify([sharedTextConsentVersion, owner, scope, commandID, texts]));
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", bytes))]
    .map(v => v.toString(16).padStart(2, "0")).join("");
}

export async function moderateSharedText(
  request: Request, owner: string, scope: string, commandID: string,
  submitted: string[], options: SharedTextModerationOptions,
): Promise<void> {
  const texts = text(submitted);
  if (!options.enabled || texts.length === 0) return;
  if (request.headers.get("X-Shared-Text-Owner")?.toLowerCase() !== owner.toLowerCase() ||
      request.headers.get("X-Shared-Text-Consent") !== sharedTextConsentVersion) {
    throw new SharedTextModerationError("shared_text_consent_required");
  }
  // Bound provider work in one Edge request; never truncate away unchecked text.
  if (texts.some(s => [...s].length > 4_000) || texts.reduce((sum, s) => sum + s.length, 0) > 1_000_000) {
    throw new SharedTextModerationError("shared_text_too_large");
  }
  if (!options.apiKey) throw new SharedTextModerationError("shared_text_unavailable");
  const token = await reviewToken(owner.toLowerCase(), scope, commandID, texts);
  const chunks: string[] = [];
  let chunk = "";
  for (const value of texts) {
    if (chunk && [...chunk].length + [...value].length + 1 > 4_000) { chunks.push(chunk); chunk = ""; }
    chunk += (chunk ? "\n" : "") + value;
  }
  if (chunk) chunks.push(chunk);
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 8_000);
  let needsReview = false;
  try {
    await options.admit?.(abort.signal);
    // Keep whole fields together; every chunk must pass before publication.
    // Small batches also bound non-Latin input size without limiting history rows.
    for (let offset = 0; offset < chunks.length; offset += 4) {
      const input = chunks.slice(offset, offset + 4);
      const response = await (options.fetch ?? fetch)("https://api.openai.com/v1/moderations", {
        method: "POST",
        headers: { Authorization: `Bearer ${options.apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ model: "omni-moderation-latest", input }),
        signal: abort.signal,
      });
      if (!response.ok) throw new SharedTextModerationError("shared_text_unavailable");
      const body = await response.json();
      if (!Array.isArray(body.results) || body.results.length !== input.length) {
        throw new SharedTextModerationError("shared_text_unavailable");
      }
      for (const result of body.results) {
        const decision = sharedTextDecision(result);
        if (decision === "reject") throw new SharedTextModerationError("shared_text_rejected");
        needsReview ||= decision === "review";
      }
    }
  } catch (error) {
    if (error instanceof SharedTextModerationError) throw error;
    // Do not expose provider responses, credentials, or the submitted text.
    throw new SharedTextModerationError("shared_text_unavailable");
  } finally { clearTimeout(timeout); }
  if (needsReview && request.headers.get("X-Shared-Text-Review") !== token) {
    throw new SharedTextModerationError("shared_text_review_required", token);
  }
}

export function sharedTextModerationEnvironment(): SharedTextModerationOptions {
  return {
    enabled: Deno.env.get("SHARED_TEXT_MODERATION_ENABLED") === "true",
    apiKey: Deno.env.get("OPENAI_MODERATION_API_KEY"),
  };
}
