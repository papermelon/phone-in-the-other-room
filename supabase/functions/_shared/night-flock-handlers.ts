import { parseJsonObject } from "./http.ts";
import {
  NightFlockErrorDescriptor,
  classifyNightFlockError,
  nightFlockError,
  requestIDFor,
} from "./night-flock-errors.ts";
import {
  NightFlockCommandPayload,
  validateNightFlockCommand,
  validateNightFlockState,
} from "./night-flock.ts";

export type NightFlockCaller = { id: string; isAnonymous: boolean };
export type NightFlockCommandResult = {
  accepted: boolean;
  inviteCode?: string | null;
  inviteID?: string | null;
  deleteAccount?: boolean;
  snapshot?: unknown;
};

export type NightFlockCommandDependencies = {
  authenticate(request: Request): Promise<NightFlockCaller>;
  execute(callerID: string, payload: NightFlockCommandPayload): Promise<NightFlockCommandResult>;
  deleteAccount(callerID: string): Promise<void>;
};

export type NightFlockStateDependencies = {
  authenticate(request: Request): Promise<NightFlockCaller>;
  read(callerID: string, schemaVersion: 1 | 2 | 3): Promise<unknown>;
};

const knownCommands = new Set([
  "createFlock", "createInvite", "revokeInvite", "join", "leave", "setSharing", "block", "report",
  "publishCheckIn", "react", "deleteNightFlockData", "deleteAccount", "createParty", "previewInvite",
  "redeemInvite", "acceptGoal", "setLocalSetup", "setSharingPreferences", "setRoutineIdeas", "startChallenge",
  "publishProgress", "publishNightMetrics", "acknowledgeGrant", "replaceInvite",
]);

function response(body: Record<string, unknown>, status: number, requestID: string): Response {
  return new Response(JSON.stringify({ ...body, requestID }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "X-Request-ID": requestID },
  });
}

function errorBody(descriptor: NightFlockErrorDescriptor, requestID: string): Response {
  return response({
    error: descriptor.error,
    code: descriptor.code,
    retryable: descriptor.retryable,
    recovery: descriptor.recovery,
  }, descriptor.status, requestID);
}

function elapsedBucket(startedAt: number): string {
  const elapsed = Date.now() - startedAt;
  if (elapsed < 50) return "0-49ms";
  if (elapsed < 200) return "50-199ms";
  if (elapsed < 1000) return "200-999ms";
  return "1000ms+";
}

export function nightFlockCompletionLogRecord(
  endpoint: string,
  requestID: string,
  elapsedDurationBucket: string,
  body: Record<string, unknown> | null,
  status: number,
  descriptor: NightFlockErrorDescriptor | null,
): Record<string, unknown> {
  const schemaVersion = body?.schemaVersion === 1 || body?.schemaVersion === 2 || body?.schemaVersion === 3
    ? body.schemaVersion
    : null;
  const command = typeof body?.command === "string" && knownCommands.has(body.command) ? body.command : "unknown";
  return {
    requestID,
    endpoint,
    schemaVersion,
    command,
    status,
    code: descriptor?.code ?? "ok",
    outcome: descriptor ? "error" : "success",
    elapsedDurationBucket,
  };
}

function completionLog(
  endpoint: string,
  requestID: string,
  startedAt: number,
  body: Record<string, unknown> | null,
  status: number,
  descriptor: NightFlockErrorDescriptor | null,
): void {
  console.info(JSON.stringify(nightFlockCompletionLogRecord(
    endpoint,
    requestID,
    elapsedBucket(startedAt),
    body,
    status,
    descriptor,
  )));
}

function requestIDFrom(request: Request): string {
  return requestIDFor(request.headers.get("X-Request-ID"));
}

async function parseBody(request: Request): Promise<Record<string, unknown>> {
  return parseJsonObject(request);
}

export async function handleNightFlockCommand(
  request: Request,
  dependencies: NightFlockCommandDependencies,
): Promise<Response> {
  const startedAt = Date.now();
  const requestID = requestIDFrom(request);
  if (request.method !== "POST") {
    const descriptor = nightFlockError("method_not_allowed");
    completionLog("night-flock-command", requestID, startedAt, null, descriptor.status, descriptor);
    return errorBody(descriptor, requestID);
  }
  let body: Record<string, unknown> | null = null;
  try {
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) {
      const descriptor = nightFlockError("linked_account_required");
      completionLog("night-flock-command", requestID, startedAt, null, descriptor.status, descriptor);
      return errorBody(descriptor, requestID);
    }
    body = await parseBody(request);
    const payload = validateNightFlockCommand(
      body,
      request.headers.get("idempotency-key"),
    );
    const result = await dependencies.execute(caller.id, payload);
    if (result.deleteAccount) await dependencies.deleteAccount(caller.id);
    const output = response({ schemaVersion: payload.schemaVersion, ...result }, 200, requestID);
    completionLog("night-flock-command", requestID, startedAt, body, 200, null);
    return output;
  } catch (error) {
    const descriptor = classifyNightFlockError(error);
    completionLog("night-flock-command", requestID, startedAt, body, descriptor.status, descriptor);
    return errorBody(descriptor, requestID);
  }
}

export async function handleNightFlockState(
  request: Request,
  dependencies: NightFlockStateDependencies,
): Promise<Response> {
  const startedAt = Date.now();
  const requestID = requestIDFrom(request);
  if (request.method !== "POST") {
    const descriptor = nightFlockError("method_not_allowed");
    completionLog("night-flock-state", requestID, startedAt, null, descriptor.status, descriptor);
    return errorBody(descriptor, requestID);
  }
  let body: Record<string, unknown> | null = null;
  try {
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) {
      const descriptor = nightFlockError("linked_account_required");
      completionLog("night-flock-state", requestID, startedAt, null, descriptor.status, descriptor);
      return errorBody(descriptor, requestID);
    }
    body = await parseBody(request);
    const stateContract = validateNightFlockState(body);
    const snapshot = await dependencies.read(caller.id, stateContract.schemaVersion);
    const output = response({ schemaVersion: stateContract.schemaVersion, snapshot }, 200, requestID);
    completionLog("night-flock-state", requestID, startedAt, body, 200, null);
    return output;
  } catch (error) {
    const descriptor = classifyNightFlockError(error);
    completionLog("night-flock-state", requestID, startedAt, body, descriptor.status, descriptor);
    return errorBody(descriptor, requestID);
  }
}
