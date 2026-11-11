// Checks the Cloudflare Access token on a request. Access already guards the
// hostname; this makes the Worker refuse requests even if Access were
// misconfigured or bypassed.
import { createRemoteJWKSet, jwtVerify } from "jose";

export class AccessError extends Error {}

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
  if (!team || !audience || !allowed) throw new AccessError("Access is not configured");

  let issuer;
  try { issuer = new URL(team).origin; } catch { throw new AccessError("Access is not configured"); }

  const token = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!token) throw new AccessError("No Access token");

  let payload;
  try {
    ({ payload } = await jwtVerify(token, keySet ?? remoteKeys(issuer), {
      issuer, audience, algorithms: ["RS256"], requiredClaims: ["exp", "email"], clockTolerance: 30,
    }));
  } catch (e) {
    throw new AccessError(e.message);
  }
  if (String(payload.email ?? "").toLowerCase() !== allowed.toLowerCase()) throw new AccessError("Not allowed");
  return payload;
}
