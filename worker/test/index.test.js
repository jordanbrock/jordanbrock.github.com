import { beforeAll, describe, expect, it, vi } from "vitest";
import { handle } from "../src/index.js";
import { env, makeKeys } from "./keys.js";

const ORIGIN = "https://post.example.com";
const now = new Date("2026-11-11T06:03:09Z");
// The smallest JPEG validate() accepts: SOI, a frame, a scan, data, EOI.
const jpeg = new Uint8Array([
  0xff, 0xd8,
  0xff, 0xc0, 0, 11, 8, 0, 16, 0, 16, 1, 1, 0x11, 0,
  0xff, 0xda, 0, 8, 1, 1, 0, 0, 63, 0,
  1, 2, 3,
  0xff, 0xd9,
]);
let keys;
beforeAll(async () => { keys = await makeKeys(); });

function request({ token, fields = {}, photos = [], origin = ORIGIN, method = "POST", path = "/posts" } = {}) {
  const headers = { Origin: origin };
  if (token) headers["Cf-Access-Jwt-Assertion"] = token;
  if (method === "GET") return new Request(`${ORIGIN}${path}`, { headers });
  const form = new FormData();
  for (const [k, v] of Object.entries({ kind: "note", content: "Hello there", ...fields })) form.append(k, v);
  for (const p of photos) {
    form.append("photo", new File([p.bytes ?? jpeg], "p.jpg", { type: "image/jpeg" }));
    form.append("alt", p.alt ?? "Alt");
    form.append("caption", p.caption ?? "");
  }
  return new Request(`${ORIGIN}${path}`, { method, body: form, headers });
}

function fakeGitHub(taken = []) {
  return { exists: vi.fn(async (p) => taken.includes(p)), commit: vi.fn(async () => "sha") };
}

const run = async (req, { github = fakeGitHub(), envOverrides = {} } = {}) => {
  const res = await handle(req, { ...env, ...envOverrides }, { keySet: keys.keySet, github, now });
  return { res, body: res.headers.get("Content-Type")?.includes("json") ? await res.json() : await res.text(), github };
};

describe("POST /posts", () => {
  it("commits a note and returns its URL", async () => {
    const { res, body, github } = await run(request({ token: await keys.sign() }));
    expect(res.status).toBe(201);
    expect(body).toEqual({ url: "https://jordanbrock.com/2026/11/11/hello-there/", path: "src/_posts/2026-11-11-hello-there.md" });
    expect(github.commit).toHaveBeenCalledWith(
      [{ path: "src/_posts/2026-11-11-hello-there.md", content: '---\ndate: "2026-11-11 14:03:09 +0800"\n---\nHello there\n' }],
      "Post: hello-there",
      { name: "Author", email: "author@example.com" },
    );
  });

  it("commits an album's photos with its post", async () => {
    const { res, github } = await run(request({
      token: await keys.sign(),
      fields: { kind: "photos", content: "", title: "Lake" },
      photos: [{ alt: "A" }, { alt: "B" }],
    }));
    expect(res.status).toBe(201);
    const [files] = github.commit.mock.calls[0];
    expect(files.map((f) => f.path)).toEqual(["src/_posts/2026-11-11-lake.md", "src/photos/2026/lake/01.jpg", "src/photos/2026/lake/02.jpg"]);
    expect(files[1].content).toEqual(jpeg);
  });

  it("picks the next free slug when the post or its photos already exist", async () => {
    const github = fakeGitHub(["src/_posts/2026-11-11-hello-there.md"]);
    const { body } = await run(request({ token: await keys.sign() }), { github });
    expect(body.path).toBe("src/_posts/2026-11-11-hello-there-2.md");

    // An album clashes with any existing folder, whatever its photos are called.
    const folderTaken = fakeGitHub(["src/photos/2026/lake"]);
    const { body: album } = await run(request({ token: await keys.sign(), fields: { kind: "photos", title: "Lake" }, photos: [{}, {}] }), { github: folderTaken });
    expect(album.path).toBe("src/_posts/2026-11-11-lake-2.md");
    expect(folderTaken.exists).toHaveBeenCalledWith("src/photos/2026/lake");

    // A single photo clashes with an existing file of the same name.
    const photoTaken = fakeGitHub(["src/photos/2026/sunset.jpg"]);
    const { body: single } = await run(request({ token: await keys.sign(), fields: { kind: "photos", content: "" }, photos: [{ caption: "Sunset" }] }), { github: photoTaken });
    expect(single.path).toBe("src/_posts/2026-11-11-sunset-2.md");
    expect(photoTaken.exists).toHaveBeenCalledWith("src/photos/2026/sunset.jpg");
  });

  it("gives up after five taken slugs", async () => {
    const taken = ["hello-there", "hello-there-2", "hello-there-3", "hello-there-4", "hello-there-5"].map((s) => `src/_posts/2026-11-11-${s}.md`);
    const github = fakeGitHub(taken);
    const { res, body } = await run(request({ token: await keys.sign() }), { github });
    expect(res.status).toBe(409);
    expect(body).toEqual({ error: "Couldn't find a free file name for this post." });
    expect(github.exists).toHaveBeenCalledTimes(5);
    expect(github.commit).not.toHaveBeenCalled();
  });

  it("refuses invalid posts with the reason", async () => {
    const { res, body, github } = await run(request({ token: await keys.sign(), fields: { content: " " } }));
    expect(res.status).toBe(422);
    expect(body).toEqual({ error: "Write something first." });
    expect(github.commit).not.toHaveBeenCalled();
  });

  it("refuses requests without a valid Access token, and logs why", async () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    try {
      const { res, github } = await run(request());
      expect(res.status).toBe(401);
      expect(github.exists).not.toHaveBeenCalled();
      expect(warn).toHaveBeenCalledWith("access:", "No Access token");
    } finally {
      warn.mockRestore();
    }
  });

  it("refuses posts from another origin", async () => {
    const { res } = await run(request({ token: await keys.sign(), origin: "https://evil.example" }));
    expect(res.status).toBe(403);
  });

  it("returns the post without committing in DRY_RUN", async () => {
    const { res, body, github } = await run(request({ token: await keys.sign() }), { envOverrides: { DRY_RUN: "1" } });
    expect(res.status).toBe(200);
    expect(body.markdown).toContain("Hello there");
    expect(body.files).toEqual(["src/_posts/2026-11-11-hello-there.md"]);
    expect(github.commit).not.toHaveBeenCalled();
  });

  it("reports a GitHub failure as a bad gateway", async () => {
    const github = fakeGitHub();
    github.commit.mockRejectedValue(new Error("GitHub tree failed (500)"));
    const { res, body } = await run(request({ token: await keys.sign() }), { github });
    expect(res.status).toBe(502);
    expect(body.error).toBe("Couldn't save the post: GitHub tree failed (500)");
  });
});

describe("other routes", () => {
  it("only accepts POST /posts", async () => {
    expect((await run(request({ path: "/other" }))).res.status).toBe(404);
    expect((await run(request({ method: "GET" }))).res.status).toBe(405);
  });
});
