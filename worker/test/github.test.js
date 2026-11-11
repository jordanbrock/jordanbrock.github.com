import { describe, expect, it } from "vitest";
import { BLOB_CONCURRENCY, GitHubError, SlugTakenError, github, toBase64 } from "../src/github.js";
import { env } from "./keys.js";

// A fake api.github.com: routes are keyed "METHOD /path"; every call is recorded.
function fakeGitHub(overrides = {}) {
  const calls = [];
  const routes = {
    "GET /repos/o/r/git/ref/heads/master": () => ({ object: { sha: "parent" } }),
    "GET /repos/o/r/git/commits/parent": () => ({ tree: { sha: "basetree" } }),
    "POST /repos/o/r/git/blobs": (body) => ({ sha: `blob-${body.content}` }),
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
        { path: "src/_posts/a.md", mode: "100644", type: "blob", sha: "blob-aGk=" },
        { path: "src/photos/2026/a.jpg", mode: "100644", type: "blob", sha: "blob-AQID" },
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

describe("commit details", () => {
  it("uploads at most BLOB_CONCURRENCY blobs at once and keeps tree order", async () => {
    expect(BLOB_CONCURRENCY).toBe(2);
    let inFlight = 0;
    let peak = 0;
    const base = fakeGitHub();
    const fetchImpl = async (url, init) => {
      const isBlob = init.method === "POST" && new URL(url).pathname.endsWith("/blobs");
      if (isBlob) { inFlight++; peak = Math.max(peak, inFlight); await new Promise((r) => setTimeout(r, 0)); }
      try { return await base.fetchImpl(url, init); } finally { if (isBlob) inFlight--; }
    };
    const files = ["a", "b", "c", "d", "e", "f"].map((c) => ({ path: `p/${c}`, content: c }));
    await github(env, fetchImpl).commit(files, "m", author);
    expect(peak).toBe(2);
    const tree = base.calls.find((c) => c.key.endsWith("/trees")).body.tree;
    expect(tree.map((t) => t.path)).toEqual(files.map((f) => f.path));
    expect(tree.map((t) => t.sha)).toEqual(files.map((f) => `blob-${Buffer.from(f.content).toString("base64")}`));
  });

  it("stops uploading after the first failed blob", async () => {
    let n = 0;
    const { fetchImpl, calls } = fakeGitHub({
      "POST /repos/o/r/git/blobs": (body) => (++n === 2 ? new Response("{}", { status: 500 }) : { sha: `blob-${body.content}` }),
    });
    const files = Array.from({ length: 8 }, (_, i) => ({ path: `p${i}`, content: `c${i}` }));
    await expect(github(env, fetchImpl).commit(files, "m", author)).rejects.toThrow("GitHub blob failed (500)");
    expect(calls.filter((c) => c.key.endsWith("/blobs")).length).toBeLessThan(8);
  });

  it("checks mustBeNew paths at the exact parent commit before committing", async () => {
    const { fetchImpl, calls } = fakeGitHub();
    await expect(github(env, fetchImpl).commit([{ path: "src/_posts/a b.md", content: "x" }], "m", author, { mustBeNew: ["src/_posts/a b.md"] })).resolves.toBe("new");
    const check = calls.find((c) => c.key === "GET /repos/o/r/contents/src/_posts/a%20b.md");
    expect(check.search).toBe("?ref=parent");
  });

  it("refuses with SlugTakenError when a mustBeNew path exists at the parent, without moving the branch", async () => {
    const { fetchImpl, calls } = fakeGitHub({ "GET /repos/o/r/contents/src/photos/2026/lake": () => [{ name: "01-frogmouth.jpg" }] });
    const result = github(env, fetchImpl).commit([{ path: "a", content: "x" }], "m", author, { mustBeNew: ["src/_posts/a.md", "src/photos/2026/lake"] });
    await expect(result).rejects.toBeInstanceOf(SlugTakenError);
    await expect(result).rejects.toBeInstanceOf(GitHubError);
    await expect(result).rejects.toMatchObject({ status: 409 });
    expect(calls.some((c) => c.key.startsWith("PATCH "))).toBe(false);
    expect(calls.filter((c) => c.key.includes("/contents/")).every((c) => c.search === "?ref=parent")).toBe(true);
  });

  it("re-checks mustBeNew paths at the new parent when master moved", async () => {
    let refs = 0;
    let patches = 0;
    const base = fakeGitHub({
      "GET /repos/o/r/git/ref/heads/master": () => ({ object: { sha: ++refs === 1 ? "sha1" : "sha2" } }),
      "GET /repos/o/r/git/commits/sha1": () => ({ tree: { sha: "tree1" } }),
      "GET /repos/o/r/git/commits/sha2": () => ({ tree: { sha: "tree2" } }),
      "PATCH /repos/o/r/git/refs/heads/master": () => (++patches === 1 ? new Response("{}", { status: 422 }) : {}),
    });
    const path = "/repos/o/r/contents/src/_posts/a.md";
    const fetchImpl = (url, init) => {
      const u = new URL(url);
      if (u.pathname === path && u.search === "?ref=sha2") {
        base.calls.push({ key: `GET ${path}`, search: u.search });
        return Promise.resolve(Response.json({}));
      }
      return base.fetchImpl(url, init);
    };
    const result = github(env, fetchImpl).commit([{ path: "src/_posts/a.md", content: "x" }], "m", author, { mustBeNew: ["src/_posts/a.md"] });
    await expect(result).rejects.toBeInstanceOf(SlugTakenError);
    expect(base.calls.filter((c) => c.key === `GET ${path}`).map((c) => c.search)).toEqual(["?ref=sha1", "?ref=sha2"]);
    expect(patches).toBe(1);
  });

  it("throws a GitHubError when a mustBeNew check fails some other way", async () => {
    const { fetchImpl } = fakeGitHub({ "GET /repos/o/r/contents/x": () => new Response("{}", { status: 500 }) });
    await expect(github(env, fetchImpl).commit([{ path: "x", content: "x" }], "m", author, { mustBeNew: ["x"] })).rejects.toThrow(new GitHubError("GitHub lookup failed (500)", 500));
  });

  it("does not mutate the caller's files", async () => {
    const files = [{ path: "a", content: new Uint8Array([1]) }];
    await github(env, fakeGitHub().fetchImpl).commit(files, "m", author);
    expect(files[0].content).toEqual(new Uint8Array([1]));
    expect(Object.keys(files[0])).toEqual(["path", "content"]);
  });

  it("includes GitHub's message in the error", async () => {
    const { fetchImpl } = fakeGitHub({ "POST /repos/o/r/git/trees": () => Response.json({ message: "Bad path" }, { status: 422 }) });
    await expect(github(env, fetchImpl).commit([{ path: "a", content: "x" }], "m", author)).rejects.toThrow("GitHub tree failed (422): Bad path");
  });

  it("truncates long messages", async () => {
    const { fetchImpl } = fakeGitHub({ "POST /repos/o/r/git/trees": () => Response.json({ message: "x".repeat(500) }, { status: 422 }) });
    await expect(github(env, fetchImpl).commit([{ path: "a", content: "x" }], "m", author)).rejects.toThrow(`GitHub tree failed (422): ${"x".repeat(200)}`);
  });

  it("encodes the branch name per segment", async () => {
    const { fetchImpl, calls } = fakeGitHub({
      "GET /repos/o/r/git/ref/heads/feat/a%20b": () => ({ object: { sha: "parent" } }),
      "PATCH /repos/o/r/git/refs/heads/feat/a%20b": () => ({}),
    });
    await github({ ...env, GITHUB_BRANCH: "feat/a b" }, fetchImpl).commit([{ path: "a", content: "x" }], "m", author);
    expect(calls.some((c) => c.key === "PATCH /repos/o/r/git/refs/heads/feat/a%20b")).toBe(true);
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
