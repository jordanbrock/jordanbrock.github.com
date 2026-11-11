import { describe, expect, it } from "vitest";
import { buildPost, perthParts, slugify } from "../src/post.js";

const now = new Date("2026-11-11T06:03:09Z"); // 14:03:09 in Perth
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
const input = (o) => ({ kind: "note", content: "", url: "", title: "", tags: [], photos: [], ...o });

describe("perthParts", () => {
  it("gives the Perth date, time and year", () => {
    expect(perthParts(now)).toEqual({ date: "2026-11-11", time: "14:03:09", year: "2026" });
  });

  it("rolls over at Perth midnight, not UTC midnight", () => {
    expect(perthParts(new Date("2026-12-31T16:30:00Z"))).toEqual({ date: "2027-01-01", time: "00:30:00", year: "2027" });
  });
});

describe("slugify", () => {
  it("lowercases and hyphenates words", () => {
    expect(slugify("Birdwalk at Herdsman Lake!", "x")).toBe("birdwalk-at-herdsman-lake");
  });

  it("drops accents, URLs and anything past six words", () => {
    expect(slugify("Caf\u00e9 d\u00e9j\u00e0 vu https://example.com/a b c d e f", "x")).toBe("cafe-deja-vu-b-c-d");
  });

  it("falls back when nothing usable is left", () => {
    expect(slugify("\ud83e\udd86 \ud83e\udd86", "note")).toBe("note");
    expect(slugify("", "photo")).toBe("photo");
  });
});

describe("buildPost", () => {
  it("writes a note with its date and tags", () => {
    const post = buildPost(input({ content: "Saw a heron today.\r\n\r\nNice.", tags: [" birds ", ""] }), now);
    expect(post.slug).toBe("saw-a-heron-today-nice");
    expect(post.path).toBe("src/_posts/2026-11-11-saw-a-heron-today-nice.md");
    expect(post.url).toBe("https://jordanbrock.com/2026/11/11/saw-a-heron-today-nice/");
    expect(post.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntemplate_engine: "none"\ntags: ["birds"]\n---\nSaw a heron today.\n\nNice.\n');
    expect(post.photos).toEqual([]);
  });

  it("writes a link with an optional title, slugged from the title or the domain", () => {
    const titled = buildPost(input({ kind: "link", url: " https://www.example.com/a ", title: 'Say "hi": now', content: "Worth a read." }), now);
    expect(titled.slug).toBe("say-hi-now");
    expect(titled.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntemplate_engine: "none"\ntitle: "Say \\"hi\\": now"\nlink: "https://www.example.com/a"\n---\nWorth a read.\n');

    const bare = buildPost(input({ kind: "link", url: "https://www.example.com/a" }), now);
    expect(bare.slug).toBe("example-com");
    expect(bare.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntemplate_engine: "none"\nlink: "https://www.example.com/a"\n---\n');
  });

  it("writes one photo as a photo post whose body is the caption", () => {
    const post = buildPost(input({ kind: "photos", photos: [{ bytes: jpeg, alt: " A street\nat night ", caption: "Night street." }] }), now);
    expect(post.slug).toBe("night-street");
    expect(post.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntemplate_engine: "none"\nimage: "2026/night-street.jpg"\nalt: "A street at night"\n---\nNight street.\n');
    expect(post.photos).toEqual([{ path: "src/photos/2026/night-street.jpg", bytes: jpeg }]);
  });

  it("writes several photos as an album with numbered images", () => {
    const post = buildPost(input({
      kind: "photos", title: "Herdsman", content: "A walk.",
      photos: [{ bytes: jpeg, alt: "A", caption: "First" }, { bytes: jpeg, alt: "B", caption: "" }],
    }), now);
    expect(post.slug).toBe("herdsman");
    expect(post.markdown).toBe([
      "---",
      'date: "2026-11-11 14:03:09 +0800"',
      'template_engine: "none"',
      'title: "Herdsman"',
      "photos:",
      '  - image: "2026/herdsman/01.jpg"',
      '    alt: "A"',
      '    caption: "First"',
      '  - image: "2026/herdsman/02.jpg"',
      '    alt: "B"',
      "---",
      "A walk.",
      "",
    ].join("\n"));
    expect(post.photos.map((p) => p.path)).toEqual(["src/photos/2026/herdsman/01.jpg", "src/photos/2026/herdsman/02.jpg"]);
  });

  it("adds -n to the slug, paths and URL when asked", () => {
    const post = buildPost(input({ kind: "photos", photos: [{ bytes: jpeg, alt: "A", caption: "Dusk" }] }), now, 2);
    expect(post.slug).toBe("dusk-2");
    expect(post.path).toBe("src/_posts/2026-11-11-dusk-2.md");
    expect(post.url).toBe("https://jordanbrock.com/2026/11/11/dusk-2/");
    expect(post.photos[0].path).toBe("src/photos/2026/dusk-2.jpg");
  });

  it("cleans control characters out of front matter strings", () => {
    const dirty = "a\u007fb\u0085c";
    const photo = buildPost(input({ kind: "photos", photos: [{ bytes: jpeg, alt: dirty, caption: "Dusk" }], tags: [dirty] }), now);
    expect(photo.markdown).toContain('alt: "a b c"');
    expect(photo.markdown).toContain('tags: ["a b c"]');
    const link = buildPost(input({ kind: "link", url: "https://example.com/", title: dirty }), now);
    expect(link.markdown).toContain('title: "a b c"');
  });

  it("writes link URLs in normalised form", () => {
    const post = buildPost(input({ kind: "link", url: "https://b\u00fccher.de/caf\u00e9 a" }), now);
    expect(post.markdown).toContain('link: "https://xn--bcher-kva.de/caf%C3%A9%20a"');
  });

  it("turns off ERB for every kind, so <% %> in a post stays text", () => {
    const erb = "Try <%= 1 + 1 %> and <%# a comment %>.";
    for (const i of [
      input({ content: erb }),
      input({ kind: "link", url: "https://example.com/", content: erb }),
      input({ kind: "photos", content: erb, photos: [{ bytes: jpeg, alt: "A", caption: "" }] }),
      input({ kind: "photos", content: erb, photos: [{ bytes: jpeg, alt: "A", caption: "" }, { bytes: jpeg, alt: "B", caption: "" }] }),
    ]) {
      const { markdown } = buildPost(i, now);
      expect(markdown).toMatch(/^---\ndate: "[^"]+"\ntemplate_engine: "none"\n/);
      expect(markdown).toContain(erb);
    }
  });

  it("keeps the intro text of a single photo post after its caption", () => {
    const post = buildPost(input({ kind: "photos", content: "Long day.", photos: [{ bytes: jpeg, alt: "A", caption: "Dusk." }] }), now);
    expect(post.markdown.endsWith("---\nDusk.\n\nLong day.\n")).toBe(true);
    expect(post.slug).toBe("dusk-long-day");
  });

  it("nests a link's preview and writes its image next to the year's photos", () => {
    const bytes = new Uint8Array([1]);
    const post = buildPost(input({
      kind: "link", url: "https://example.com/s", title: "A story",
      preview: { title: "A story: long", description: "Says \"hi\"", site: "Example", bytes },
    }), now);
    expect(post.markdown).toBe([
      "---",
      'date: "2026-11-11 14:03:09 +0800"',
      'template_engine: "none"',
      'title: "A story"',
      'link: "https://example.com/s"',
      "preview:",
      '  title: "A story: long"',
      '  description: "Says \\"hi\\""',
      '  site: "Example"',
      '  image: "2026/a-story-preview.jpg"',
      "---",
      "",
    ].join("\n"));
    expect(post.photos).toEqual([{ path: "src/photos/2026/a-story-preview.jpg", bytes }]);
  });

  it("leaves out an empty preview, and the image when there isn't one", () => {
    const base = { kind: "link", url: "https://example.com/s", title: "A story" };
    expect(buildPost(input({ ...base, preview: { title: "", description: "", site: "", bytes: null } }), now).markdown).not.toContain("preview");
    const textOnly = buildPost(input({ ...base, preview: { title: "T", description: "", site: "", bytes: null } }), now);
    expect(textOnly.markdown).toContain('preview:\n  title: "T"\n---');
    expect(textOnly.photos).toEqual([]);
  });
});

describe("slugify limits", () => {
  it("caps slugs at 60 characters", () => {
    expect(slugify("a".repeat(100), "x")).toBe("a".repeat(60));
  });

  it("transliterates letters NFKD leaves alone", () => {
    expect(slugify("Stra\u00dfe \u00c6r\u00f8", "x")).toBe("strasse-aero");
  });
});
