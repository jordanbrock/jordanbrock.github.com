import { describe, expect, it } from "vitest";
import { MAX_PHOTO_BYTES, MAX_PHOTOS, ValidationError, isJpeg, unsafeJpeg, validate } from "../src/validate.js";

const ascii = (s) => [...s].map((c) => c.charCodeAt(0));
const seg = (marker, payload) => [0xff, marker, (payload.length + 2) >> 8, (payload.length + 2) & 0xff, ...payload];
const SOI = [0xff, 0xd8];
const EOI = [0xff, 0xd9];
const app0 = seg(0xe0, ascii("JFIF\0\x01\x01"));
const app1 = seg(0xe1, ascii("Exif\0\0MM"));
const sof = seg(0xc0, [8, 0, 16, 0, 16, 1, 1, 0x11, 0]);
const sos = seg(0xda, [1, 1, 0, 0, 63, 0]);
const data = [1, 2, 0xff, 0, 3];
const jpeg = (...parts) => new Uint8Array(parts.flat());
const clean = jpeg(SOI, app0, sof, sos, data, EOI);
const withExif = jpeg(SOI, app0, app1, sof, sos, data, EOI);
const withXmp = jpeg(SOI, seg(0xe1, ascii("http://ns.adobe.com/xap/1.0/\0<x/>")), sof, sos, data, EOI);
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
    fails({ kind: "link", url: "http:foo" }, "Links must start with http:// or https://.");
  });

  it("needs at least one photo, and not too many", () => {
    expect(MAX_PHOTOS).toBe(25); // keeps a post inside the Workers Free plan's 50 subrequests
    fails({ kind: "photos" }, "Add at least one photo.");
    fails({ kind: "photos", photos: Array.from({ length: 26 }, () => photo()) }, "At most 25 photos per post.");
    fails({ kind: "photos", photos: Array.from({ length: MAX_PHOTOS + 1 }, () => photo()) }, `At most ${MAX_PHOTOS} photos per post.`);
  });

  it("refuses photos that add up to more than 40 MB", () => {
    const chunk = new Uint8Array(9 * 1024 * 1024);
    fails({ kind: "photos", photos: Array.from({ length: 5 }, () => photo({ bytes: chunk })) }, "These photos add up to more than 40 MB. Post them in two goes.");
  });

  it("names the photo that's missing alt text", () => {
    fails({ kind: "photos", photos: [photo(), photo({ alt: " " })] }, "Photo 2 needs alt text.");
  });

  it("refuses photos that are too big, not JPEG, or still carry camera data", () => {
    const big = new Uint8Array(MAX_PHOTO_BYTES + 1); big.set([0xff, 0xd8, 0xff]);
    fails({ kind: "photos", photos: [photo({ bytes: big })] }, "Photo 1 is over 10 MB.");
    fails({ kind: "photos", photos: [photo({ bytes: png })] }, "Photo 1 isn't a JPEG.");
    fails({ kind: "photos", photos: [photo({ bytes: withExif })] }, "Photo 1 has camera data (EXIF or XMP) or isn't a clean JPEG. Choose it again on the posting page.");
  });
});

describe("JPEG checks", () => {
  it("spots JPEGs by their first bytes", () => {
    expect(isJpeg(clean)).toBe(true);
    expect(isJpeg(png)).toBe(false);
  });

  it("accepts a clean, well-formed JPEG", () => {
    expect(unsafeJpeg(clean)).toBe(false);
  });

  it("refuses APP1 segments (EXIF or XMP)", () => {
    expect(unsafeJpeg(withExif)).toBe(true);
    expect(unsafeJpeg(withXmp)).toBe(true);
    expect(unsafeJpeg(jpeg(SOI, app0, app1, sof, sos, data, EOI))).toBe(true);
  });

  it("refuses odd bytes that libjpeg skips before a later APP1", () => {
    expect(unsafeJpeg(jpeg(SOI, app0, [0x00], app1, sof, sos, data, EOI))).toBe(true);
    expect(unsafeJpeg(jpeg(SOI, app0, [0xff, 0x01], app1, sof, sos, data, EOI))).toBe(true);
    expect(unsafeJpeg(jpeg(SOI, app0, [0xff, 0x00], app1, sof, sos, data, EOI))).toBe(true);
  });

  it("refuses a second JPEG with APP1 after EOI", () => {
    expect(unsafeJpeg(jpeg(clean, withExif))).toBe(true);
  });

  it("refuses files that are not a well-formed run of segments", () => {
    expect(unsafeJpeg(jpeg(SOI, app0, sos, data, EOI))).toBe(true); // no frame
    expect(unsafeJpeg(jpeg(SOI, app0, seg(0xc0, [8, 0, 16, 0, 0, 1, 1, 0x11, 0]), sos, data, EOI))).toBe(true); // zero width
    expect(unsafeJpeg(jpeg(SOI, app0, seg(0xc0, []), sof, sos, data, EOI))).toBe(true); // frame too short
    expect(unsafeJpeg(jpeg(SOI, app0, sof, sof, sos, data, EOI))).toBe(true); // two frames
    expect(unsafeJpeg(jpeg(SOI, app0, sof))).toBe(true); // truncated before SOS
    expect(unsafeJpeg(jpeg(clean, [0, 0]))).toBe(true); // trailing bytes after EOI
    expect(unsafeJpeg(png)).toBe(true);
  });
});
