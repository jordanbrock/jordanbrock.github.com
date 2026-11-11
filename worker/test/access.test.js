import { beforeAll, describe, expect, it } from "vitest";
import { SignJWT, errors, generateKeyPair } from "jose";
import { AccessConfigError, AccessError, verifyAccess } from "../src/access.js";
import { AUD, EMAIL, TEAM, env, makeKeys } from "./keys.js";

let keys;
beforeAll(async () => { keys = await makeKeys(); });

const req = (token, url = "https://post.example.com/posts") =>
  new Request(url, { method: "POST", headers: token ? { "Cf-Access-Jwt-Assertion": token } : {} });

describe("verifyAccess", () => {
  it("accepts a valid token for the allowed email, in any case", async () => {
    const payload = await verifyAccess(req(await keys.sign({ email: EMAIL.toUpperCase() })), env, keys.keySet);
    expect(payload.email).toBe(EMAIL.toUpperCase());
  });

  it("refuses a missing, expired, wrong-audience, wrong-issuer or wrong-email token", async () => {
    const past = Math.floor(Date.now() / 1000) - 60;
    for (const token of [
      undefined,
      await keys.sign({ exp: past }),
      await keys.sign({ aud: "other" }),
      await keys.sign({ iss: "https://evil.cloudflareaccess.com" }),
      await keys.sign({ email: "someone@example.com" }),
      await keys.sign({ exp: null }),
      "not.a.jwt",
    ]) {
      const error = await verifyAccess(req(token), env, keys.keySet).catch((e) => e);
      expect(error).toBeInstanceOf(AccessError);
      expect(error).not.toBeInstanceOf(AccessConfigError); // a bad token is a sign-in problem
    }
  });

  it("fails closed when Access isn't configured", async () => {
    const token = await keys.sign();
    const result = verifyAccess(req(token), { ...env, ACCESS_AUD: "" }, keys.keySet);
    await expect(result).rejects.toThrow("Access is not configured");
    await expect(result).rejects.toBeInstanceOf(AccessConfigError);
  });

  it("accepts a team domain written with a trailing slash", async () => {
    const token = await keys.sign();
    await expect(verifyAccess(req(token), { ...env, ACCESS_TEAM_DOMAIN: TEAM + "/" }, keys.keySet)).resolves.toMatchObject({ email: EMAIL });
  });

  it("fails closed when the team domain isn't a URL", async () => {
    const token = await keys.sign();
    const result = verifyAccess(req(token), { ...env, ACCESS_TEAM_DOMAIN: "not a url" }, keys.keySet);
    await expect(result).rejects.toThrow("Access is not configured");
    await expect(result).rejects.toBeInstanceOf(AccessConfigError);
  });

  it("refuses a token signed by a key that isn't in the key set as a sign-in problem", async () => {
    const { privateKey } = await generateKeyPair("RS256");
    const token = await new SignJWT({ email: EMAIL }).setProtectedHeader({ alg: "RS256", kid: "k2" })
      .setIssuer(TEAM).setAudience(AUD).setIssuedAt().setExpirationTime("1h").sign(privateKey);
    const error = await verifyAccess(req(token), env, keys.keySet).catch((e) => e);
    expect(error).toBeInstanceOf(AccessError);
    expect(error).not.toBeInstanceOf(AccessConfigError);
  });

  it("treats a failed key fetch as a setup problem, not a sign-in problem", async () => {
    const token = await keys.sign();
    for (const failure of [new errors.JWKSTimeout(), new errors.JOSEError("Expected 200 OK from the JSON Web Key Set HTTP response"), new TypeError("fetch failed")]) {
      const keySet = async () => { throw failure; };
      await expect(verifyAccess(req(token), env, keySet)).rejects.toBeInstanceOf(AccessConfigError);
    }
  });

  it("skips the check only for localhost with DEV_SKIP_ACCESS", async () => {
    const dev = { ...env, DEV_SKIP_ACCESS: "1" };
    await expect(verifyAccess(req(undefined, "http://localhost:8787/posts"), dev, keys.keySet)).resolves.toEqual({ email: "dev@localhost" });
    await expect(verifyAccess(req(undefined), dev, keys.keySet)).rejects.toBeInstanceOf(AccessError);
  });
});
