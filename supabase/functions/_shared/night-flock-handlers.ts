import { parseJsonObject } from "./http.ts";
import {
  NightFlockErrorDescriptor,
  classifyNightFlockError,
  nightFlockError,
  requestIDFor,
} from "./night-flock-errors.ts";
import {
  NightFlockCommandPayload,
  NightFlockStateContract,
  validateNightFlockCommand,
  validateNightFlockState,
} from "./night-flock.ts";
import { adaptSharedHabitsStateWire } from "./night-flock-shared-habits-wire.ts";

export type NightFlockCaller = { id: string; isAnonymous: boolean };
export type NightFlockCommandResult = Record<string, unknown> & {
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
  prepare?(payload: NightFlockCommandPayload): Promise<{
    payload: NightFlockCommandPayload;
    transform(result: NightFlockCommandResult): Promise<NightFlockCommandResult>;
  }>;
};

export type NightFlockStateDependencies = {
  authenticate(request: Request): Promise<NightFlockCaller>;
  read(callerID: string, contract: NightFlockStateContract): Promise<unknown>;
};

const knownCommands = new Set([
  "createFlock", "createInvite", "revokeInvite", "join", "leave", "setSharing", "block", "report",
  "publishCheckIn", "react", "deleteNightFlockData", "deleteAccount", "createParty", "previewInvite",
  "redeemInvite", "acceptGoal", "setLocalSetup", "setSharingPreferences", "setRoutineIdeas", "startChallenge",
  "publishProgress", "publishNightMetrics", "acknowledgeUpdateCheer", "acknowledgeGrant", "replaceInvite", "renameParty", "startRound",
  "retrieveInvite", "leaveParty", "deleteParty", "updatePublicProfile", "publishActivity", "completeBackfill", "publishStatus",
  "blockMember", "reportMember", "cheerMember",
  "movePastureEntity", "contributePastureSheep", "recallPastureSheep", "setCampfireSharing", "publishCampfireSession", "campfireBuddyAction", "setCampfireAlerts",
  "acceptSharedHabitsAgreement", "publishSharedHabit", "deleteSharedHabitHistory", "migrateSharedHabits",
  "publishSharedNightPlan", "cancelSharedNightPlan", "publishSharedNightReceipt",
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

type RequestStage = "request" | "authenticate" | "validate" | "prepare" | "read" | "execute" | "transform" | "deleteAccount" | "serialize";

class RequestTiming {
  private startedAt = performance.now();
  private stageStartedAt = this.startedAt;
  stage: RequestStage = "request";
  durations: Partial<Record<RequestStage, number>> = {};

  enter(stage: RequestStage): void {
    const now = performance.now();
    this.durations[this.stage] = Math.round(now - this.stageStartedAt);
    this.stageStartedAt = now;
    this.stage = stage;
  }

  fields(): Record<string, unknown> {
    this.enter(this.stage);
    return { stage: this.stage, elapsedMs: Math.round(performance.now() - this.startedAt), stageDurationsMs: this.durations };
  }
}

// Never record upstream messages/details/hints: they can contain private row values.
export function nightFlockUpstreamDiagnostics(error: unknown): Record<string, unknown> {
  const failure = error && typeof error === "object" ? error as Record<string, unknown> : {};
  const allowedSQLStates = new Set([
    "08000", "08001", "08003", "08006", "08007", "08P01", "22001", "22003", "22007", "22P02",
    "23502", "23503", "23505", "23514", "40001", "40P01", "42501", "42601", "42702", "42703",
    "42883", "42P01", "53300", "53400", "54001", "55000", "57014", "57P01", "57P02", "57P03", "P0001", "XX000",
  ]);
  const code = typeof failure.code === "string" && (allowedSQLStates.has(failure.code) || /^PGRST[0-9]{3}$/.test(failure.code))
    ? failure.code : null;
  const status = typeof failure.status === "number" && Number.isInteger(failure.status) && failure.status >= 100 && failure.status <= 599
    ? failure.status : null;
  return { upstreamCode: code, upstreamStatus: status };
}

export function nightFlockCompletionLogRecord(
  endpoint: string,
  requestID: string,
  elapsedDurationBucket: string,
  body: Record<string, unknown> | null,
  status: number,
  descriptor: NightFlockErrorDescriptor | null,
): Record<string, unknown> {
  const schemaVersion = body?.schemaVersion === 1 || body?.schemaVersion === 2 || body?.schemaVersion === 3 || body?.schemaVersion === 4
    ? body.schemaVersion
    : null;
  const command = typeof body?.command === "string" && knownCommands.has(body.command) ? body.command : "unknown";
  return {
    requestID,
    endpoint,
    schemaVersion,
    command,
    scope: typeof body?.scope === "string" && ["list", "party", "habits", "sharedNights"].includes(body.scope) ? body.scope : null,
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
  timing: RequestTiming,
  error?: unknown,
): void {
  console.info(JSON.stringify({ ...nightFlockCompletionLogRecord(
    endpoint,
    requestID,
    elapsedBucket(startedAt),
    body,
    status,
    descriptor,
  ), ...timing.fields(), ...nightFlockUpstreamDiagnostics(error) }));
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
  const timing = new RequestTiming();
  const requestID = requestIDFrom(request);
  if (request.method !== "POST") {
    const descriptor = nightFlockError("method_not_allowed");
    completionLog("night-flock-command", requestID, startedAt, null, descriptor.status, descriptor, timing);
    return errorBody(descriptor, requestID);
  }
  let body: Record<string, unknown> | null = null;
  try {
    timing.enter("authenticate");
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) {
      const descriptor = nightFlockError("linked_account_required");
      completionLog("night-flock-command", requestID, startedAt, null, descriptor.status, descriptor, timing);
      return errorBody(descriptor, requestID);
    }
    timing.enter("validate");
    body = await parseBody(request);
    const payload = validateNightFlockCommand(
      body,
      request.headers.get("idempotency-key"),
    );
    timing.enter("prepare");
    const prepared = dependencies.prepare ? await dependencies.prepare(payload) : null;
    timing.enter("execute");
    const result = await dependencies.execute(caller.id, prepared?.payload ?? payload);
    timing.enter("transform");
    const publicResult = prepared ? await prepared.transform(result) : result;
    if (result.deleteAccount) {
      timing.enter("deleteAccount");
      await dependencies.deleteAccount(caller.id);
    }
    timing.enter("serialize");
    const output = response({ schemaVersion: payload.schemaVersion, ...publicResult }, 200, requestID);
    completionLog("night-flock-command", requestID, startedAt, body, 200, null, timing);
    return output;
  } catch (error) {
    const descriptor = classifyNightFlockError(error);
    completionLog("night-flock-command", requestID, startedAt, body, descriptor.status, descriptor, timing, error);
    return errorBody(descriptor, requestID);
  }
}

export async function handleNightFlockState(
  request: Request,
  dependencies: NightFlockStateDependencies,
): Promise<Response> {
  const startedAt = Date.now();
  const timing = new RequestTiming();
  const requestID = requestIDFrom(request);
  if (request.method !== "POST") {
    const descriptor = nightFlockError("method_not_allowed");
    completionLog("night-flock-state", requestID, startedAt, null, descriptor.status, descriptor, timing);
    return errorBody(descriptor, requestID);
  }
  let body: Record<string, unknown> | null = null;
  try {
    timing.enter("authenticate");
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) {
      const descriptor = nightFlockError("linked_account_required");
      completionLog("night-flock-state", requestID, startedAt, null, descriptor.status, descriptor, timing);
      return errorBody(descriptor, requestID);
    }
    timing.enter("validate");
    body = await parseBody(request);
    const stateContract = validateNightFlockState(body);
    timing.enter("read");
    const snapshot = await dependencies.read(caller.id, stateContract);
    timing.enter("serialize");
    const wireSnapshot = stateContract.schemaVersion === 4 && (stateContract.scope === "habits" || stateContract.scope === "sharedNights")
      ? adaptSharedHabitsStateWire(snapshot)
      : snapshot;
    const output = response({ schemaVersion: stateContract.schemaVersion, snapshot: wireSnapshot }, 200, requestID);
    completionLog("night-flock-state", requestID, startedAt, body, 200, null, timing);
    return output;
  } catch (error) {
    const descriptor = classifyNightFlockError(error);
    completionLog("night-flock-state", requestID, startedAt, body, descriptor.status, descriptor, timing, error);
    return errorBody(descriptor, requestID);
  }
}
