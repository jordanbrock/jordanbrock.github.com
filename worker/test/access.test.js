import { beforeAll, describe, expect, it } from "vitest";
import { AccessError, verifyAccess } from "../src/access.js";
import { EMAIL, env, makeKeys } from "./keys.js";

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
      "not.a.jwt",
    ]) {
      await expect(verifyAccess(req(token), env, keys.keySet)).rejects.toBeInstanceOf(AccessError);
    }
  });

  it("fails closed when Access isn't configured", async () => {
    const token = await keys.sign();
    await expect(verifyAccess(req(token), { ...env, ACCESS_AUD: "" }, keys.keySet)).rejects.toThrow("Access is not configured");
  });

  it("skips the check only for localhost with DEV_SKIP_ACCESS", async () => {
    const dev = { ...env, DEV_SKIP_ACCESS: "1" };
    await expect(verifyAccess(req(undefined, "http://localhost:8787/posts"), dev, keys.keySet)).resolves.toEqual({ email: "dev@localhost" });
    await expect(verifyAccess(req(undefined), dev, keys.keySet)).rejects.toBeInstanceOf(AccessError);
  });
});
