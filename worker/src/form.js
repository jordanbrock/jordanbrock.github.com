// Reads the posting page's multipart form into posting input. Photos arrive
// as repeated photo/alt/caption fields, in post order.
import { MAX_PHOTO_BYTES, ValidationError, checkPhotoBudget } from "./validate.js";

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

  // A link's preview image, re-encoded by the page like a photo.
  const previewFile = form.get("preview_image");
  form.delete("preview_image");
  if (previewFile !== null && kind !== "link") throw new ValidationError("Only links can have a preview image.");
  if (typeof previewFile === "string") throw new ValidationError("The preview image didn't upload as a file.");
  if (previewFile && previewFile.size > MAX_PHOTO_BYTES) throw new ValidationError("The preview image is over 10 MB.");
  const preview = kind === "link" ? {
    title: str("preview_title"),
    description: str("preview_description"),
    site: str("preview_site"),
    bytes: previewFile ? new Uint8Array(await previewFile.arrayBuffer()) : null,
  } : null;

  return {
    kind,
    content: str("content"),
    url: str("url"),
    title: str("title"),
    // "#Photography #tech" and "photography, tech" both give the site's
    // lowercase, single-word tags.
    tags: [...new Set(str("tags").split(/[\s,]+/).map((t) => t.replace(/^#+/, "").toLowerCase()).filter(Boolean))],
    preview,
    photos,
  };
}
