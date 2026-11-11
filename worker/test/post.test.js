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
    expect(slugify("Café déjà vu https://example.com/a b c d e f", "x")).toBe("cafe-deja-vu-b-c-d");
  });

  it("falls back when nothing usable is left", () => {
    expect(slugify("🦆 🦆", "note")).toBe("note");
    expect(slugify("", "photo")).toBe("photo");
  });
});

describe("buildPost", () => {
  it("writes a note with its date and tags", () => {
    const post = buildPost(input({ content: "Saw a heron today.\r\n\r\nNice.", tags: [" birds ", ""] }), now);
    expect(post.slug).toBe("saw-a-heron-today-nice");
    expect(post.path).toBe("src/_posts/2026-11-11-saw-a-heron-today-nice.md");
    expect(post.url).toBe("https://jordanbrock.com/2026/11/11/saw-a-heron-today-nice/");
    expect(post.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntags: ["birds"]\n---\nSaw a heron today.\n\nNice.\n');
    expect(post.photos).toEqual([]);
  });

  it("writes a link with an optional title, slugged from the title or the domain", () => {
    const titled = buildPost(input({ kind: "link", url: " https://www.example.com/a ", title: 'Say "hi": now', content: "Worth a read." }), now);
    expect(titled.slug).toBe("say-hi-now");
    expect(titled.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\ntitle: "Say \\"hi\\": now"\nlink: "https://www.example.com/a"\n---\nWorth a read.\n');

    const bare = buildPost(input({ kind: "link", url: "https://www.example.com/a" }), now);
    expect(bare.slug).toBe("example-com");
    expect(bare.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\nlink: "https://www.example.com/a"\n---\n');
  });

  it("writes one photo as a photo post whose body is the caption", () => {
    const post = buildPost(input({ kind: "photos", photos: [{ bytes: jpeg, alt: " A street\nat night ", caption: "Night street." }] }), now);
    expect(post.slug).toBe("night-street");
    expect(post.markdown).toBe('---\ndate: "2026-11-11 14:03:09 +0800"\nimage: "2026/night-street.jpg"\nalt: "A street at night"\n---\nNight street.\n');
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
});
