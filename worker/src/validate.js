// Refuses posting input the site's build would reject, or that could leak
// where a photo was taken. A post that broke the build would block every
// deploy, so the Worker checks first.

export class ValidationError extends Error {}

export const MAX_PHOTOS = 30;
export const MAX_PHOTO_BYTES = 10 * 1024 * 1024;
const KINDS = ["note", "link", "photos"];

export function validate(input) {
  const fail = (message) => { throw new ValidationError(message); };

  if (!KINDS.includes(input.kind)) fail("Choose Note, Link or Photos.");
  if (input.kind === "note" && !input.content.trim()) fail("Write something first.");

  if (input.kind === "link") {
    let url;
    try { url = new URL(input.url.trim()); } catch { fail("That link isn't a valid URL."); }
    if (!["http:", "https:"].includes(url.protocol) || !url.hostname) fail("Links must start with http:// or https://.");
  }

  if (input.kind === "photos") {
    if (input.photos.length === 0) fail("Add at least one photo.");
    if (input.photos.length > MAX_PHOTOS) fail(`At most ${MAX_PHOTOS} photos per post.`);
    input.photos.forEach((photo, i) => {
      const n = i + 1;
      if (!photo.alt.trim()) fail(`Photo ${n} needs alt text.`);
      if (photo.bytes.length > MAX_PHOTO_BYTES) fail(`Photo ${n} is over 10 MB.`);
      if (!isJpeg(photo.bytes)) fail(`Photo ${n} isn't a JPEG.`);
      if (hasCameraData(photo.bytes)) fail(`Photo ${n} still has camera data (EXIF or XMP), which can include where it was taken.`);
    });
  }
}

export const isJpeg = (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

// True when the JPEG has an APP1 segment (EXIF or XMP, either of which can
// hold GPS) before its image data. The posting page's re-encoded JPEGs have none.
export function hasCameraData(b) {
  let i = 2;
  while (i + 4 <= b.length && b[i] === 0xff) {
    const marker = b[i + 1];
    if (marker === 0xff) { i += 1; continue; } // fill byte
    if (marker === 0xda || marker === 0xd9) break; // start of scan / end of image
    if (marker === 0xe1) return true;
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return false;
}
