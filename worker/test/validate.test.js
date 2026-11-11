import { describe, expect, it } from "vitest";
import { MAX_PHOTO_BYTES, MAX_PHOTOS, ValidationError, hasCameraData, isJpeg, validate } from "../src/validate.js";

const ascii = (s) => [...s].map((c) => c.charCodeAt(0));
const seg = (marker, payload) => [0xff, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xff, ...payload];
const clean = new Uint8Array([0xff, 0xd8, ...seg(0xe0, ascii("JFIF\0\x01\x01")), 0xff, 0xda, 0, 2, 0xff, 0xd9]);
const withExif = new Uint8Array([0xff, 0xd8, ...seg(0xe0, ascii("JFIF\0")), ...seg(0xe1, ascii("Exif\0\0MM")), 0xff, 0xda, 0, 2]);
const withXmp = new Uint8Array([0xff, 0xd8, ...seg(0xe1, ascii("http://ns.adobe.com/xap/1.0/\0<x/>")), 0xff, 0xda, 0, 2]);
const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);

const input = (o) => ({ kind: "note", content: "", url: "", title: "", tags: [], photos: [], ...o });
const photo = (o) => ({ bytes: clean, alt: "A heron", caption: "", ...o });
const fails = (i, message) => expect(() => validate(input(i))).toThrow(new ValidationError(message));

describe("validate", () => {
  it("accepts a note, a link and photos", () => {
    expect(() => validate(input({ content: "Hi" }))).not.toThrow();
    expect(() => validate(input({ kind: "link", url: "https://example.com/" }))).not.toThrow();
    expect(() => validate(input({ kind: "photos", photos: [photo(), photo()] }))).not.toThrow();
  });

  it("needs a known kind", () => fails({ kind: "article" }, "Choose Note, Link or Photos."));
  it("needs words in a note", () => fails({ content: "  \n" }, "Write something first."));
  it("needs a valid link", () => fails({ kind: "link", url: "not a url" }, "That link isn't a valid URL."));
  it("needs an http(s) link", () => {
    fails({ kind: "link", url: "javascript:alert(1)" }, "Links must start with http:// or https://.");
    fails({ kind: "link", url: "ftp://example.com/" }, "Links must start with http:// or https://.");
  });

  it("needs at least one photo, and not too many", () => {
    fails({ kind: "photos" }, "Add at least one photo.");
    fails({ kind: "photos", photos: Array.from({ length: MAX_PHOTOS + 1 }, () => photo()) }, `At most ${MAX_PHOTOS} photos per post.`);
  });

  it("names the photo that's missing alt text", () => {
    fails({ kind: "photos", photos: [photo(), photo({ alt: " " })] }, "Photo 2 needs alt text.");
  });

  it("refuses photos that are too big, not JPEG, or still carry camera data", () => {
    const big = new Uint8Array(MAX_PHOTO_BYTES + 1); big.set([0xff, 0xd8, 0xff]);
    fails({ kind: "photos", photos: [photo({ bytes: big })] }, "Photo 1 is over 10 MB.");
    fails({ kind: "photos", photos: [photo({ bytes: png })] }, "Photo 1 isn't a JPEG.");
    fails({ kind: "photos", photos: [photo({ bytes: withExif })] }, "Photo 1 still has camera data (EXIF or XMP), which can include where it was taken.");
  });
});

describe("JPEG checks", () => {
  it("spots JPEGs by their first bytes", () => {
    expect(isJpeg(clean)).toBe(true);
    expect(isJpeg(png)).toBe(false);
  });

  it("finds APP1 segments (EXIF or XMP) before the image data", () => {
    expect(hasCameraData(clean)).toBe(false);
    expect(hasCameraData(withExif)).toBe(true);
    expect(hasCameraData(withXmp)).toBe(true);
  });
});
