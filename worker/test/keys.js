// A signing key and an env for tests; stands in for Cloudflare Access.
import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from "jose";

export const TEAM = "https://example.cloudflareaccess.com";
export const AUD = "test-aud";
export const EMAIL = "owner@example.com";

export const env = {
  ACCESS_TEAM_DOMAIN: TEAM, ACCESS_AUD: AUD, ALLOWED_EMAIL: EMAIL,
  GITHUB_REPO: "o/r", GITHUB_BRANCH: "master", GITHUB_TOKEN: "t",
  AUTHOR_NAME: "Author", AUTHOR_EMAIL: "author@example.com",
};

export async function makeKeys() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256" };
  const keySet = createLocalJWKSet({ keys: [jwk] });
  const sign = ({ email = EMAIL, aud = AUD, iss = TEAM, exp = "1h" } = {}) => {
    const jwt = new SignJWT({ email }).setProtectedHeader({ alg: "RS256", kid: "k1" })
      .setIssuer(iss).setAudience(aud).setIssuedAt();
    if (exp !== null) jwt.setExpirationTime(exp);
    return jwt.sign(privateKey);
  };
  return { keySet, sign };
}
