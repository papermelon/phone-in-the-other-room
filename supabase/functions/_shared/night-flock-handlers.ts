import { errorResponse, json, parseJsonObject } from "./http.ts";
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

export async function handleNightFlockCommand(
  request: Request,
  dependencies: NightFlockCommandDependencies,
): Promise<Response> {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) return json({ error: "Linked account required" }, 403);
    const body = await parseJsonObject(request);
    const payload = validateNightFlockCommand(
      body,
      request.headers.get("idempotency-key"),
    );
    const result = await dependencies.execute(caller.id, payload);
    if (result.deleteAccount) await dependencies.deleteAccount(caller.id);
    return json({ schemaVersion: payload.schemaVersion, ...result });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function handleNightFlockState(
  request: Request,
  dependencies: NightFlockStateDependencies,
): Promise<Response> {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const caller = await dependencies.authenticate(request);
    if (caller.isAnonymous) return json({ error: "Linked account required" }, 403);
    const stateContract = validateNightFlockState(await parseJsonObject(request));
    const snapshot = await dependencies.read(caller.id, stateContract.schemaVersion);
    return json({ schemaVersion: stateContract.schemaVersion, snapshot });
  } catch (error) {
    return errorResponse(error);
  }
}
