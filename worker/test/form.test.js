import { describe, expect, it } from "vitest";
import { parseForm } from "../src/form.js";
import { ValidationError } from "../src/validate.js";

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
      kind: "photos", content: "", url: "", title: "T", tags: ["birds", "perth"],
      photos: [
        { bytes: new Uint8Array([1]), alt: "One", caption: "First" },
        { bytes: new Uint8Array([2]), alt: "Two", caption: "" },
      ],
    });
  });

  it("refuses a photo field that isn't a file", async () => {
    const form = new FormData();
    form.append("kind", "photos");
    form.append("photo", "oops");
    await expect(parseForm(form)).rejects.toBeInstanceOf(ValidationError);
  });
});
