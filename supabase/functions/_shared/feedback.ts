export const feedbackCategories = ["bug", "featureRequest", "general"] as const;

export type FeedbackCategory = (typeof feedbackCategories)[number];

export type FeedbackDiagnostics = {
  appVersion: string;
  buildNumber: string;
  operatingSystem: string;
  deviceFamily: string;
};

export type ValidatedFeedback = {
  submissionID: string;
  category: FeedbackCategory;
  message: string;
  replyEmail: string | null;
  diagnostics: FeedbackDiagnostics | null;
  attachmentPaths: string[];
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function validateFeedbackPayload(
  body: Record<string, unknown>,
  authenticatedUserID: string,
): ValidatedFeedback {
  if (body.schemaVersion !== 1) throw new Error("Unsupported schemaVersion");

  const submissionIDValue = requiredString(body.submissionID, "submissionID");
  if (!uuidPattern.test(submissionIDValue)) {
    throw new Error("Invalid submissionID");
  }
  const submissionID = submissionIDValue.toLowerCase();

  const category = requiredString(body.category, "category");
  if (!feedbackCategories.includes(category as FeedbackCategory)) {
    throw new Error("Invalid category");
  }

  const message = requiredString(body.message, "message").trim();
  if (message.length < 10 || message.length > 4_000) {
    throw new Error("Message must contain 10 to 4000 characters");
  }

  const replyEmail = optionalString(body.replyEmail, "replyEmail");
  if (
    replyEmail && (replyEmail.length > 254 || !emailPattern.test(replyEmail))
  ) {
    throw new Error("Invalid replyEmail");
  }

  const attachmentPaths = stringArray(body.attachmentPaths, "attachmentPaths");
  if (attachmentPaths.length > 3) throw new Error("Too many attachments");
  const expectedPrefix =
    `${authenticatedUserID.toLowerCase()}/${submissionID}/`;
  for (const [index, path] of attachmentPaths.entries()) {
    if (path !== `${expectedPrefix}attachment-${index + 1}.jpg`) {
      throw new Error("Invalid attachment path");
    }
  }

  const diagnostics = validateDiagnostics(body.diagnostics);
  return {
    submissionID,
    category: category as FeedbackCategory,
    message,
    replyEmail,
    diagnostics,
    attachmentPaths,
  };
}

function validateDiagnostics(value: unknown): FeedbackDiagnostics | null {
  if (value === undefined || value === null) return null;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid diagnostics");
  }
  const diagnostics = value as Record<string, unknown>;
  return {
    appVersion: boundedString(diagnostics.appVersion, "appVersion", 64),
    buildNumber: boundedString(diagnostics.buildNumber, "buildNumber", 64),
    operatingSystem: boundedString(
      diagnostics.operatingSystem,
      "operatingSystem",
      64,
    ),
    deviceFamily: boundedString(diagnostics.deviceFamily, "deviceFamily", 64),
  };
}

function requiredString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Missing ${name}`);
  }
  return value;
}

function boundedString(value: unknown, name: string, maximum: number): string {
  const text = requiredString(value, name);
  if (text.length > maximum) throw new Error(`Invalid ${name}`);
  return text;
}

function optionalString(value: unknown, name: string): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string") throw new Error(`Invalid ${name}`);
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function stringArray(value: unknown, name: string): string[] {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new Error(`Invalid ${name}`);
  }
  return value as string[];
}
