// Reads the posting page's multipart form into posting input. Photos arrive
// as repeated photo/alt/caption fields, in post order.
import { ValidationError } from "./validate.js";

export async function parseForm(form) {
  const str = (key) => String(form.get(key) ?? "");
  const alts = form.getAll("alt").map(String);
  const captions = form.getAll("caption").map(String);

  const photos = [];
  for (const [i, file] of form.getAll("photo").entries()) {
    if (typeof file === "string") throw new ValidationError(`Photo ${i + 1} didn't upload as a file.`);
    photos.push({ bytes: new Uint8Array(await file.arrayBuffer()), alt: alts[i] ?? "", caption: captions[i] ?? "" });
  }

  return {
    kind: str("kind"),
    content: str("content"),
    url: str("url"),
    title: str("title"),
    tags: str("tags").split(",").map((t) => t.trim()).filter(Boolean),
    photos,
  };
}
