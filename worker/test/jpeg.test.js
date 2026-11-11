import { describe, expect, it } from "vitest";
import { stripMetadata } from "../public/jpeg.js";
import { unsafeJpeg } from "../src/validate.js";

const SOI = [0xff, 0xd8];
const APP0 = [0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00];
const APP1 = [0xff, 0xe1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
// SOF0: 8-bit, 1x1, one component.
const SOF = [0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00];
const SOS = [0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00];
const DATA = [0x12, 0x34, 0xff, 0x00, 0x56];
const EOI = [0xff, 0xd9];

const jpeg = (...parts) => new Uint8Array(parts.flat());

describe("stripMetadata", () => {
  it("removes APP1 and keeps APP0, SOF, SOS and the data", () => {
    const out = stripMetadata(jpeg(SOI, APP0, APP1, SOF, SOS, DATA, EOI));
    expect([...out]).toEqual([...jpeg(SOI, APP0, SOF, SOS, DATA, EOI)]);
  });

  it("removes every APP1 segment", () => {
    const out = stripMetadata(jpeg(SOI, APP1, APP0, APP1, SOF, SOS, DATA, EOI));
    expect([...out]).toEqual([...jpeg(SOI, APP0, SOF, SOS, DATA, EOI)]);
  });

  it("returns a JPEG with no metadata byte for byte", () => {
    const input = jpeg(SOI, APP0, SOF, SOS, DATA, EOI);
    expect([...stripMetadata(input)]).toEqual([...input]);
  });

  it("returns malformed input unchanged", () => {
    const cases = [
      jpeg([0x89, 0x50, 0x4e, 0x47]), // not a JPEG
      jpeg(SOI, [0x00, 0xe1, 0x00, 0x08], APP1.slice(4), SOS, EOI), // not FF at a marker
      jpeg(SOI, APP1.slice(0, 2), [0x01, 0x00], APP1.slice(4)), // length past the end
      jpeg(SOI, APP1, [0xff, 0xd0], SOF, SOS, EOI), // no-length marker in the header
      jpeg(SOI, APP0, APP1), // no SOS
    ];
    for (const input of cases) expect(stripMetadata(input)).toBe(input);
  });

  it("makes a well-formed JPEG with APP1 pass the server's check", () => {
    const input = jpeg(SOI, APP0, APP1, SOF, SOS, DATA, EOI);
    expect(unsafeJpeg(input)).toBe(true);
    expect(unsafeJpeg(stripMetadata(input))).toBe(false);
  });

  it("removes every application segment and comment the server would refuse", () => {
    const seg = (marker, text) => [0xff, marker, 0, text.length + 2, ...[...text].map((c) => c.charCodeAt(0))];
    const ICC = seg(0xe2, "ICC_PROFILE\0\x01\x01");
    const ADOBE = seg(0xee, "Adobe\0\x64\0\0\0\0\x01");
    const refused = [seg(0xe0, "JFXX\0"), APP1, seg(0xe2, "MPF\0"), seg(0xe5, "x"), seg(0xed, "Photoshop 3.0\0"), seg(0xee, "Other"), seg(0xef, "x"), seg(0xfe, "comment")];
    const input = jpeg(SOI, APP0, ...refused, ICC, ADOBE, SOF, SOS, DATA, EOI);
    expect(unsafeJpeg(input)).toBe(true);
    const out = stripMetadata(input);
    expect([...out]).toEqual([...jpeg(SOI, APP0, ICC, ADOBE, SOF, SOS, DATA, EOI)]);
    expect(unsafeJpeg(out)).toBe(false);
  });
});
