// Checks the Cloudflare Access token on a request. Access already guards the
// hostname; this makes the Worker refuse requests even if Access were
// misconfigured or bypassed.
import { createRemoteJWKSet, jwtVerify } from "jose";

export class AccessError extends Error {}
// The Worker's Access settings or Cloudflare's keys are at fault, not the visitor.
export class AccessConfigError extends AccessError {}

const LOCAL_HOSTS = ["localhost", "127.0.0.1"];
const keySets = new Map(); // team domain -> remote key set (cached per isolate)

function remoteKeys(team) {
  if (!keySets.has(team)) keySets.set(team, createRemoteJWKSet(new URL("/cdn-cgi/access/certs", team)));
  return keySets.get(team);
}

// Resolves to the token's claims, or throws AccessError. keySet is for tests.
export async function verifyAccess(request, env, keySet) {
  if (env.DEV_SKIP_ACCESS === "1" && LOCAL_HOSTS.includes(new URL(request.url).hostname)) return { email: "dev@localhost" };

  const { ACCESS_TEAM_DOMAIN: team, ACCESS_AUD: audience, ALLOWED_EMAIL: allowed } = env;
  if (!team || !audience || !allowed) throw new AccessConfigError("Access is not configured");

  let issuer;
  try { issuer = new URL(team).origin; } catch { throw new AccessConfigError("Access is not configured"); }

  const token = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!token) throw new AccessError("No Access token");

  // A key set failure is a setup problem (timeout, fetch error, bad key set),
  // except when no key matches the token's, which is the token's fault.
  const keys = keySet ?? remoteKeys(issuer);
  const guardedKeys = async (...args) => {
    try {
      return await keys(...args);
    } catch (e) {
      if (e?.code === "ERR_JWKS_NO_MATCHING_KEY" || e?.code === "ERR_JWKS_MULTIPLE_MATCHING_KEYS") throw e;
      throw new AccessConfigError(`Access keys unavailable: ${e?.message}`);
    }
  };

  let payload;
  try {
    ({ payload } = await jwtVerify(token, guardedKeys, {
      issuer, audience, algorithms: ["RS256"], requiredClaims: ["exp", "email"], clockTolerance: 30,
    }));
  } catch (e) {
    if (e instanceof AccessError) throw e;
    throw new AccessError(e.message);
  }
  if (String(payload.email ?? "").toLowerCase() !== allowed.toLowerCase()) throw new AccessError("Not allowed");
  return payload;
}
