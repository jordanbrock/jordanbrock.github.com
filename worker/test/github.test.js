import { describe, expect, it } from "vitest";
import { GitHubError, github, toBase64 } from "../src/github.js";
import { env } from "./keys.js";

// A fake api.github.com: routes are keyed "METHOD /path"; every call is recorded.
function fakeGitHub(overrides = {}) {
  const calls = [];
  const routes = {
    "GET /repos/o/r/git/ref/heads/master": () => ({ object: { sha: "parent" } }),
    "GET /repos/o/r/git/commits/parent": () => ({ tree: { sha: "basetree" } }),
    "POST /repos/o/r/git/blobs": () => ({ sha: `blob${calls.filter((c) => c.key.endsWith("/blobs")).length}` }),
    "POST /repos/o/r/git/trees": () => ({ sha: "tree" }),
    "POST /repos/o/r/git/commits": () => ({ sha: "new" }),
    "PATCH /repos/o/r/git/refs/heads/master": () => ({}),
    ...overrides,
  };
  const fetchImpl = async (url, init) => {
    const u = new URL(url);
    const key = `${init.method} ${u.pathname}`;
    const body = init.body ? JSON.parse(init.body) : undefined;
    calls.push({ key, body, search: u.search, headers: init.headers });
    const route = routes[key];
    if (!route) return new Response("{}", { status: 404 });
    const result = route(body);
    return result instanceof Response ? result : Response.json(result);
  };
  return { fetchImpl, calls };
}

const author = { name: "Author", email: "author@example.com" };

describe("commit", () => {
  it("makes one commit holding every file, on top of the branch", async () => {
    const { fetchImpl, calls } = fakeGitHub();
    const sha = await github(env, fetchImpl).commit(
      [{ path: "src/_posts/a.md", content: "hi" }, { path: "src/photos/2026/a.jpg", content: new Uint8Array([1, 2, 3]) }],
      "Post: a", author,
    );
    expect(sha).toBe("new");
    expect(calls[0].headers.Authorization).toBe("Bearer t");
    expect(calls.filter((c) => c.key.endsWith("/blobs")).map((c) => c.body)).toEqual([
      { content: "aGk=", encoding: "base64" },
      { content: "AQID", encoding: "base64" },
    ]);
    expect(calls.find((c) => c.key.endsWith("/trees")).body).toEqual({
      base_tree: "basetree",
      tree: [
        { path: "src/_posts/a.md", mode: "100644", type: "blob", sha: "blob1" },
        { path: "src/photos/2026/a.jpg", mode: "100644", type: "blob", sha: "blob2" },
      ],
    });
    expect(calls.find((c) => c.key === "POST /repos/o/r/git/commits").body).toEqual({ message: "Post: a", tree: "tree", parents: ["parent"], author });
    expect(calls.at(-1)).toMatchObject({ key: "PATCH /repos/o/r/git/refs/heads/master", body: { sha: "new", force: false } });
  });

  it("retries once when master moved, then gives up", async () => {
    let patches = 0;
    const once = fakeGitHub({ "PATCH /repos/o/r/git/refs/heads/master": () => (++patches === 1 ? new Response("{}", { status: 422 }) : {}) });
    await expect(github(env, once.fetchImpl).commit([{ path: "a", content: "x" }], "m", author)).resolves.toBe("new");
    expect(once.calls.filter((c) => c.key.endsWith("/blobs"))).toHaveLength(1); // blobs aren't re-sent

    const always = fakeGitHub({ "PATCH /repos/o/r/git/refs/heads/master": () => new Response("{}", { status: 422 }) });
    await expect(github(env, always.fetchImpl).commit([{ path: "a", content: "x" }], "m", author)).rejects.toThrow(new GitHubError("GitHub ref update failed (422)", 422));
  });

  it("reports which GitHub call failed", async () => {
    const { fetchImpl } = fakeGitHub({ "POST /repos/o/r/git/trees": () => new Response("{}", { status: 500 }) });
    await expect(github(env, fetchImpl).commit([{ path: "a", content: "x" }], "m", author)).rejects.toThrow("GitHub tree failed (500)");
  });
});

describe("exists", () => {
  it("looks the path up on the branch", async () => {
    const { fetchImpl, calls } = fakeGitHub({ "GET /repos/o/r/contents/src/_posts/a%20b.md": () => ({}) });
    const gh = github(env, fetchImpl);
    expect(await gh.exists("src/_posts/a b.md")).toBe(true);
    expect(calls[0].search).toBe("?ref=master");
    expect(await gh.exists("src/_posts/missing.md")).toBe(false);
  });

  it("throws on other errors rather than guessing", async () => {
    const { fetchImpl } = fakeGitHub({ "GET /repos/o/r/contents/x": () => new Response("{}", { status: 500 }) });
    await expect(github(env, fetchImpl).exists("x")).rejects.toThrow("GitHub lookup failed (500)");
  });
});

describe("toBase64", () => {
  it("matches Node's encoder on large input", () => {
    const bytes = Uint8Array.from({ length: 100_003 }, (_, i) => (i * 31) % 256);
    expect(toBase64(bytes)).toBe(Buffer.from(bytes).toString("base64"));
  });
});
