// Reads the posting page's multipart form into posting input. Photos arrive
// as repeated photo/alt/caption fields, in post order.
import { ValidationError, checkPhotoBudget } from "./validate.js";

export async function parseForm(form) {
  const str = (key) => String(form.get(key) ?? "");
  const alts = form.getAll("alt").map(String);
  const captions = form.getAll("caption").map(String);

  const kind = str("kind");
  const files = form.getAll("photo");
  form.delete("photo"); // so each file can be dropped once read
  if (kind !== "photos" && files.length > 0) throw new ValidationError("Notes and links can't have photos.");

  // Check the count and total size before reading any bytes.
  files.forEach((file, i) => {
    if (typeof file === "string") throw new ValidationError(`Photo ${i + 1} didn't upload as a file.`);
  });
  checkPhotoBudget(files.length, files.reduce((sum, file) => sum + file.size, 0));

  const photos = [];
  for (let i = 0; i < files.length; i++) {
    const bytes = new Uint8Array(await files[i].arrayBuffer());
    files[i] = null;
    photos.push({ bytes, alt: alts[i] ?? "", caption: captions[i] ?? "" });
  }

  return {
    kind,
    content: str("content"),
    url: str("url"),
    title: str("title"),
    // "#Photography #tech" and "photography, tech" both give the site's
    // lowercase, single-word tags.
    tags: [...new Set(str("tags").split(/[\s,]+/).map((t) => t.replace(/^#+/, "").toLowerCase()).filter(Boolean))],
    photos,
  };
}
