// Invitation plaintext exists only at the Edge boundary. Database payloads carry an
// AES-GCM envelope and digest; completion logs intentionally never receive either.
export type NightFlockInviteEnvelope = {
  inviteCiphertext: string;
  inviteNonce: string;
  inviteKeyVersion: number;
};

export type NightFlockInviteCrypto = {
  randomValues(values: Uint8Array): Uint8Array;
  encrypt(key: CryptoKey, nonce: Uint8Array, plaintext: Uint8Array): Promise<ArrayBuffer>;
  decrypt(key: CryptoKey, nonce: Uint8Array, ciphertext: Uint8Array): Promise<ArrayBuffer>;
  importKey(raw: Uint8Array): Promise<CryptoKey>;
  digest(plaintext: Uint8Array): Promise<ArrayBuffer>;
};

const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const encoder = new TextEncoder();
const decoder = new TextDecoder();

const webCrypto: NightFlockInviteCrypto = {
  randomValues: (values) => crypto.getRandomValues(values),
  encrypt: (key, nonce, plaintext) => crypto.subtle.encrypt({ name: "AES-GCM", iv: arrayBuffer(nonce) }, key, arrayBuffer(plaintext)),
  decrypt: (key, nonce, ciphertext) => crypto.subtle.decrypt({ name: "AES-GCM", iv: arrayBuffer(nonce) }, key, arrayBuffer(ciphertext)),
  importKey: (raw) => crypto.subtle.importKey("raw", arrayBuffer(raw), { name: "AES-GCM" }, false, ["encrypt", "decrypt"]),
  digest: (plaintext) => crypto.subtle.digest("SHA-256", arrayBuffer(plaintext)),
};

export function invitationKeyFromEnvironment(environment = Deno.env): { version: number; key: Uint8Array } {
  const version = Number(environment.get("NIGHT_FLOCK_INVITE_KEY_VERSION") ?? "1");
  if (!Number.isSafeInteger(version) || version < 1 || version > 99) throw new Error("Invite encryption unavailable");
  return invitationKeyForVersion(version, environment);
}

export function invitationKeyForVersion(version: number, environment = Deno.env): { version: number; key: Uint8Array } {
  if (!Number.isSafeInteger(version) || version < 1 || version > 99) throw new Error("Invite encryption unavailable");
  const encoded = environment.get(`NIGHT_FLOCK_INVITE_KEY_V${version}`);
  if (!encoded) throw new Error("Invite encryption unavailable");
  const key = decodeBase64(encoded);
  if (key.length !== 32) throw new Error("Invite encryption unavailable");
  return { version, key };
}

export async function createInvitation(
  keyMaterial: Uint8Array,
  keyVersion: number,
  cryptoProvider: NightFlockInviteCrypto = webCrypto,
): Promise<{ shortCode: string; digest: string; envelope: NightFlockInviteEnvelope }> {
  const random = cryptoProvider.randomValues(new Uint8Array(24));
  const shortCode = Array.from(random.slice(0, 12), (value) => alphabet[value % alphabet.length]).join("");
  const key = await cryptoProvider.importKey(keyMaterial);
  const nonce = random.slice(12, 24);
  const plaintext = encoder.encode(shortCode);
  const [ciphertext, digest] = await Promise.all([
    cryptoProvider.encrypt(key, nonce, plaintext),
    cryptoProvider.digest(plaintext),
  ]);
  return {
    shortCode,
    digest: hex(new Uint8Array(digest)),
    envelope: { inviteCiphertext: base64(new Uint8Array(ciphertext)), inviteNonce: base64(nonce), inviteKeyVersion: keyVersion },
  };
}

export async function decryptInvitation(
  envelope: NightFlockInviteEnvelope,
  keyMaterial: Uint8Array,
  cryptoProvider: NightFlockInviteCrypto = webCrypto,
): Promise<string> {
  if (!Number.isSafeInteger(envelope.inviteKeyVersion) || envelope.inviteKeyVersion < 1) throw new Error("Invite encryption unavailable");
  const nonce = decodeBase64(envelope.inviteNonce);
  const ciphertext = decodeBase64(envelope.inviteCiphertext);
  if (nonce.length !== 12 || ciphertext.length < 17) throw new Error("Invite encryption unavailable");
  const plaintext = await cryptoProvider.decrypt(await cryptoProvider.importKey(keyMaterial), nonce, ciphertext);
  const shortCode = decoder.decode(plaintext);
  if (!/^[A-HJ-NP-Z2-9]{12}$/.test(shortCode)) throw new Error("Invite encryption unavailable");
  return shortCode;
}

export function redactInvitationResult(result: Record<string, unknown>): Record<string, unknown> {
  const { inviteEnvelope: _envelope, inviteCiphertext: _ciphertext, inviteNonce: _nonce, inviteDigest: _digest, ...safe } = result;
  return safe;
}

function base64(bytes: Uint8Array): string {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value);
}
function decodeBase64(value: string): Uint8Array {
  try {
    const decoded = atob(value);
    return Uint8Array.from(decoded, (char) => char.charCodeAt(0));
  } catch { throw new Error("Invite encryption unavailable"); }
}
function hex(bytes: Uint8Array): string { return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(""); }
function arrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}
