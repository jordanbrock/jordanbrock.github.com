import { describe, expect, it, vi } from "vitest";
import { parseForm } from "../src/form.js";
import { MAX_PHOTOS, ValidationError } from "../src/validate.js";

describe("parseForm", () => {
  it("reads text fields, splits tags and pairs photos with their alt text and captions", async () => {
    const form = new FormData();
    form.append("kind", "photos");
    form.append("title", "T");
    form.append("tags", " birds, perth ,, ");
    form.append("photo", new File([new Uint8Array([1])], "01.jpg"));
    form.append("alt", "One");
    form.append("caption", "First");
    form.append("photo", new File([new Uint8Array([2])], "02.jpg"));
    form.append("alt", "Two");
    form.append("caption", "");
    expect(await parseForm(form)).toEqual({
      kind: "photos", content: "", url: "", title: "T", tags: ["birds", "perth"], preview: null,
      photos: [
        { bytes: new Uint8Array([1]), alt: "One", caption: "First" },
        { bytes: new Uint8Array([2]), alt: "Two", caption: "" },
      ],
    });
  });

  it("splits tags on commas or spaces, drops #, lowercases and removes repeats", async () => {
    const form = new FormData();
    form.append("kind", "note");
    form.append("content", "Hi");
    form.append("tags", "#Photography #tech, tech ##web,,  #");
    expect((await parseForm(form)).tags).toEqual(["photography", "tech", "web"]);
  });

  it("refuses a photo field that isn't a file", async () => {
    const form = new FormData();
    form.append("kind", "photos");
    form.append("photo", "oops");
    await expect(parseForm(form)).rejects.toBeInstanceOf(ValidationError);
  });

  it("refuses photos on a note or link", async () => {
    const form = new FormData();
    form.append("kind", "note");
    form.append("content", "Hi");
    form.append("photo", new File([new Uint8Array([1])], "01.jpg"));
    await expect(parseForm(form)).rejects.toThrow(new ValidationError("Notes and links can't have photos."));
  });

  it("refuses too many or too large photos before reading any bytes", async () => {
    const read = vi.spyOn(Blob.prototype, "arrayBuffer");
    try {
      const many = new FormData();
      many.append("kind", "photos");
      for (let i = 0; i <= MAX_PHOTOS; i++) { many.append("photo", new File([new Uint8Array([i])], `${i}.jpg`)); many.append("alt", "A"); }
      await expect(parseForm(many)).rejects.toThrow(new ValidationError("At most 25 photos per post."));

      const big = new FormData();
      big.append("kind", "photos");
      const chunk = new Uint8Array(9 * 1024 * 1024);
      for (let i = 0; i < 5; i++) { big.append("photo", new File([chunk], `${i}.jpg`)); big.append("alt", "A"); }
      await expect(parseForm(big)).rejects.toThrow(new ValidationError("These photos add up to more than 40 MB. Post them in two goes."));

      expect(read).not.toHaveBeenCalled();
    } finally {
      read.mockRestore();
    }
  });

  it("reads a link's preview, with its image", async () => {
    const form = new FormData();
    form.append("kind", "link");
    form.append("url", "https://example.com/");
    form.append("preview_title", "Story");
    form.append("preview_description", "About it");
    form.append("preview_site", "Example");
    form.append("preview_image", new File([new Uint8Array([9, 8])], "preview.jpg"));
    expect((await parseForm(form)).preview).toEqual({ title: "Story", description: "About it", site: "Example", bytes: new Uint8Array([9, 8]) });
  });

  it("gives a link without a preview empty preview fields", async () => {
    const form = new FormData();
    form.append("kind", "link");
    form.append("url", "https://example.com/");
    expect((await parseForm(form)).preview).toEqual({ title: "", description: "", site: "", bytes: null });
  });

  it("treats an empty preview file as no preview image", async () => {
    for (const kind of ["link", "note"]) {
      const form = new FormData();
      form.append("kind", kind);
      form.append("preview_image", new File([], ""));
      const input = await parseForm(form);
      expect(input.preview?.bytes ?? null).toBeNull();
    }
  });

  it("refuses a preview image on photos", async () => {
    const form = new FormData();
    form.append("kind", "photos");
    form.append("preview_image", new File([new Uint8Array([1])], "p.jpg"));
    await expect(parseForm(form)).rejects.toThrow("Only links can have a preview image.");
  });

  it("refuses a preview image on anything but a link, or one that isn't a file", async () => {
    const note = new FormData();
    note.append("kind", "note");
    note.append("preview_image", new File([new Uint8Array([1])], "p.jpg"));
    await expect(parseForm(note)).rejects.toThrow("Only links can have a preview image.");
    const text = new FormData();
    text.append("kind", "link");
    text.append("preview_image", "oops");
    await expect(parseForm(text)).rejects.toThrow("The preview image didn't upload as a file.");
  });
});
