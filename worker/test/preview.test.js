import { describe, expect, it, vi } from "vitest";
import { PreviewError, fetchPreview, fetchPreviewImage, parsePreview } from "../src/preview.js";

const PAGE = "https://example.com/news/story";

describe("parsePreview", () => {
  it("reads Open Graph tags and makes the image absolute", () => {
    const html = `<html><head>
      <meta property="og:title" content="A &quot;big&quot; story">
      <meta property="og:description" content='Line one &amp; two'>
      <meta property="og:site_name" content="Example News">
      <meta property="og:image" content="/img/card.jpg">
      <title>Ignored</title></head></html>`;
    expect(parsePreview(html, PAGE)).toEqual({
      title: 'A "big" story',
      description: "Line one & two",
      site: "Example News",
      image: "https://example.com/img/card.jpg",
    });
  });

  it("falls back to Twitter tags, then <title> and the meta description", () => {
    const twitter = `<meta name="twitter:title" content="Tweet title"><meta name="twitter:image:src" content="https://cdn.example.com/t.png">`;
    expect(parsePreview(twitter, PAGE)).toEqual({ title: "Tweet title", description: "", site: "", image: "https://cdn.example.com/t.png" });
    const plain = `<title>  Plain
      title </title><meta name="description" content="Plain description">`;
    expect(parsePreview(plain, PAGE)).toEqual({ title: "Plain title", description: "Plain description", site: "", image: "" });
  });

  it("handles attribute order, case, unquoted values and numeric entities", () => {
    const html = `<META CONTENT="Caf&#233; &#x2014; menu" PROPERTY="OG:TITLE"><meta content=https://example.com/a.jpg property=og:image>`;
    expect(parsePreview(html, PAGE)).toMatchObject({ title: "Caf\u00e9 \u2014 menu", image: "https://example.com/a.jpg" });
  });

  it("drops images that aren't http(s) and caps long text", () => {
    const html = `<meta property="og:image" content="javascript:alert(1)"><meta property="og:title" content="${"x".repeat(400)}">`;
    const preview = parsePreview(html, PAGE);
    expect(preview.image).toBe("");
    expect(preview.title).toHaveLength(300);
  });

  it("returns empty fields for a page with no tags", () => {
    expect(parsePreview("", PAGE)).toEqual({ title: "", description: "", site: "", image: "" });
  });
});

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);
const page = (body, init = {}) => new Response(body, { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" }, ...init });

describe("fetchPreview", () => {
  it("fetches the page and parses it, resolving images against the final URL", async () => {
    const fetchImpl = vi.fn(async () => {
      const res = page(`<meta property="og:image" content="card.jpg"><meta property="og:title" content="T">`);
      Object.defineProperty(res, "url", { value: "https://example.com/moved/" });
      return res;
    });
    expect(await fetchPreview("https://example.com/old", fetchImpl)).toEqual({ title: "T", description: "", site: "", image: "https://example.com/moved/card.jpg" });
    const [, init] = fetchImpl.mock.calls[0];
    expect(init.headers["User-Agent"]).not.toMatch(/jordan/i);
  });

  it("refuses URLs that aren't public http(s)", async () => {
    for (const bad of ["ftp://example.com/", "http://localhost/", "http://127.0.0.1/", "http://[::1]/", "not a url"]) {
      await expect(fetchPreview(bad, vi.fn())).rejects.toMatchObject({ status: 422 });
    }
  });

  it("reports pages that fail or can't be reached", async () => {
    await expect(fetchPreview("https://example.com/", async () => page("x", { status: 404 }))).rejects.toMatchObject({ status: 502, message: "That page answered 404." });
    await expect(fetchPreview("https://example.com/", async () => { throw new TypeError("network"); })).rejects.toMatchObject({ status: 502, message: "Couldn't reach that page." });
  });

  it("returns an empty preview for a page that isn't HTML", async () => {
    const pdf = async () => new Response("%PDF", { headers: { "Content-Type": "application/pdf" } });
    expect(await fetchPreview("https://example.com/a.pdf", pdf)).toEqual({ title: "", description: "", site: "", image: "" });
  });

  it("reads only the first 1 MB of a page", async () => {
    const big = "<title>Top</title>" + " ".repeat(2 * 1024 * 1024) + '<meta property="og:title" content="Late">';
    expect((await fetchPreview("https://example.com/", async () => page(big))).title).toBe("Top");
  });
});

describe("fetchPreviewImage", () => {
  it("returns the bytes and the type sniffed from them", async () => {
    const got = await fetchPreviewImage("https://example.com/i", async () => new Response(PNG, { headers: { "Content-Type": "text/plain" } }));
    expect(got.type).toBe("image/png");
    expect([...got.bytes]).toEqual([...PNG]);
  });

  it("knows JPEG, GIF and WebP", async () => {
    const sniff = async (bytes) => (await fetchPreviewImage("https://example.com/i", async () => new Response(new Uint8Array(bytes)))).type;
    expect(await sniff([0xff, 0xd8, 0xff, 0xe0])).toBe("image/jpeg");
    expect(await sniff([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])).toBe("image/gif");
    expect(await sniff([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])).toBe("image/webp");
  });

  it("refuses non-images (including SVG), big images and bad URLs", async () => {
    await expect(fetchPreviewImage("https://example.com/i", async () => new Response("<svg></svg>"))).rejects.toMatchObject({ status: 422, message: "That isn't an image." });
    const huge = new Uint8Array(5 * 1024 * 1024 + 1);
    huge.set(PNG);
    await expect(fetchPreviewImage("https://example.com/i", async () => new Response(huge))).rejects.toMatchObject({ status: 422, message: "That image is over 5 MB." });
    await expect(fetchPreviewImage("http://localhost/i", vi.fn())).rejects.toBeInstanceOf(PreviewError);
    await expect(fetchPreviewImage("https://example.com/i", async () => new Response("x", { status: 500 }))).rejects.toMatchObject({ status: 502 });
  });
});

const stalled = (type) => async () =>
  new Response(new ReadableStream({ pull() { throw new DOMException("x", "TimeoutError"); } }), { headers: { "Content-Type": type } });
const chunked = (chunks, type = "text/html") => async () =>
  new Response(new ReadableStream({ start(c) { for (const ch of chunks) c.enqueue(ch); c.close(); } }), { headers: { "Content-Type": type } });
const enc = (s) => new TextEncoder().encode(s);

describe("failures while reading the body", () => {
  it("reports a page that stalls or resets as a 502", async () => {
    await expect(fetchPreview("https://example.com/", stalled("text/html"))).rejects.toMatchObject({ status: 502, message: "That page took too long or stopped answering." });
    await expect(fetchPreviewImage("https://example.com/i", stalled("image/png"))).rejects.toMatchObject({ status: 502 });
  });
});

describe("parsePreview details", () => {
  it("copes with > inside a quoted attribute value", () => {
    const html = `<meta property="og:title" content="a > b"><meta property="og:site_name" content="S">`;
    expect(parsePreview(html, PAGE)).toMatchObject({ title: "a > b", site: "S" });
  });

  it("decodes typographic entities and leaves surrogate code points alone", () => {
    const html = `<meta property="og:title" content="It&rsquo;s &mdash; fine &amp;#xD800; &#xD800;">`;
    expect(parsePreview(html, PAGE).title).toBe("It\u2019s \u2014 fine &#xD800; &#xD800;");
  });
});

describe("page encodings and kinds", () => {
  it("decodes with the charset from Content-Type", async () => {
    const body = new Uint8Array([...enc("<title>caf"), 0xe9, ...enc("</title>")]);
    const latin = async () => new Response(body, { headers: { "Content-Type": "text/html; charset=windows-1252" } });
    expect((await fetchPreview("https://example.com/", latin)).title).toBe("caf\u00e9");
  });

  it("falls back to UTF-8 for an unknown charset", async () => {
    const odd = async () => new Response("<title>ok</title>", { headers: { "Content-Type": "text/html; charset=bogus-9" } });
    expect((await fetchPreview("https://example.com/", odd)).title).toBe("ok");
  });

  it("uses the page itself as the image when the URL is an image", async () => {
    const fetchImpl = async () => {
      const res = new Response(PNG, { headers: { "Content-Type": "image/png" } });
      Object.defineProperty(res, "url", { value: "https://example.com/final.png" });
      return res;
    };
    expect(await fetchPreview("https://example.com/p", fetchImpl)).toEqual({ title: "", description: "", site: "", image: "https://example.com/final.png" });
  });

  it("keeps exactly the first 1 MB across several chunks", async () => {
    const MB = 1024 * 1024;
    const tag = "<title>Edge</title>";
    const build = (end) => {
      const a = new Uint8Array(600000).fill(32);
      const b = new Uint8Array(600000).fill(32);
      b.set(enc(tag), end - 600000 - tag.length);
      return [a, b, new Uint8Array(600000).fill(32)];
    };
    expect((await fetchPreview("https://example.com/", chunked(build(MB)))).title).toBe("Edge");
    expect((await fetchPreview("https://example.com/", chunked(build(MB + 1)))).title).toBe("");
  });
});
