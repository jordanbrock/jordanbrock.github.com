import { describe, expect, it } from "vitest";
import { parsePreview } from "../src/preview.js";

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
