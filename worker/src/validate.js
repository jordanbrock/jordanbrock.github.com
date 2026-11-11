// Refuses posting input the site's build would reject, or that could leak
// where a photo was taken. A post that broke the build would block every
// deploy, so the Worker checks first.

export class ValidationError extends Error {}

export const MAX_PHOTOS = 25; // keeps the worst case inside 50 subrequests (see index.js)
export const MAX_PHOTO_BYTES = 10 * 1024 * 1024;
export const MAX_POST_BYTES = 40 * 1024 * 1024; // Workers have 128 MB of memory; the bodies are held, then copied
const KINDS = ["note", "link", "photos"];

export const TOO_MANY_PHOTOS = `At most ${MAX_PHOTOS} photos per post.`;
export const TOO_BIG = "These photos add up to more than 40 MB. Post them in two goes.";

// Shared with form.js, which checks before reading the photos' bytes.
export function checkPhotoBudget(count, totalBytes) {
  if (count > MAX_PHOTOS) throw new ValidationError(TOO_MANY_PHOTOS);
  if (totalBytes > MAX_POST_BYTES) throw new ValidationError(TOO_BIG);
}

export function validate(input) {
  const fail = (message) => { throw new ValidationError(message); };

  if (!KINDS.includes(input.kind)) fail("Choose Note, Link or Photos.");
  if (input.kind === "note" && !input.content.trim()) fail("Write something first.");

  if (input.kind === "link") {
    let url;
    try { url = new URL(input.url.trim()); } catch { fail("That link isn't a valid URL."); }
    if (!/^https?:\/\//i.test(input.url.trim()) || !["http:", "https:"].includes(url.protocol) || !url.hostname) fail("Links must start with http:// or https://.");
  }

  if (input.kind === "photos") {
    if (input.photos.length === 0) fail("Add at least one photo.");
    checkPhotoBudget(input.photos.length, input.photos.reduce((sum, photo) => sum + photo.bytes.length, 0));
    input.photos.forEach((photo, i) => {
      const n = i + 1;
      if (!photo.alt.trim()) fail(`Photo ${n} needs alt text.`);
      if (photo.bytes.length > MAX_PHOTO_BYTES) fail(`Photo ${n} is over 10 MB.`);
      if (!isJpeg(photo.bytes)) fail(`Photo ${n} isn't a JPEG.`);
      if (unsafeJpeg(photo.bytes)) fail(`Photo ${n} has camera data (EXIF or XMP) or isn't a clean JPEG. Choose it again on the posting page.`);
    });
  }
}

export const isJpeg = (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

// True unless the JPEG is a clean, well-formed run of segments: SOI, header
// segments with lengths (none of them APP1, i.e. EXIF/XMP), a frame (SOFn),
// SOS, image data with no APP1, and EOI as the last two bytes. Anything odd is
// refused, because libjpeg is more forgiving than this walk and could still
// find camera data we skipped.
export function unsafeJpeg(b) {
  if (!isJpeg(b)) return true;
  let i = 2;
  let frame = false;
  for (;;) {
    if (i + 1 >= b.length || b[i] !== 0xff) return true;
    while (i + 1 < b.length && b[i + 1] === 0xff) i++; // fill bytes
    const m = b[i + 1];
    if (m === 0xda) break; // start of scan
    if (m === 0xe1) return true; // APP1: EXIF or XMP
    if (m === 0x00 || m === 0x01 || (m >= 0xd0 && m <= 0xd9)) return true; // no-length marker in the header
    if (i + 3 >= b.length) return true;
    const len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2) return true;
    if (m >= 0xc0 && m <= 0xcf && m !== 0xc4 && m !== 0xc8 && m !== 0xcc) {
      if (frame || len < 11 || i + 2 + len > b.length) return true; // second frame, or too short for 8 bytes + a component
      const height = (b[i + 5] << 8) | b[i + 6];
      const width = (b[i + 7] << 8) | b[i + 8];
      if (!height || !width) return true;
      frame = true;
    }
    i += 2 + len;
  }
  if (!frame) return true;
  for (let j = i + 2; j + 1 < b.length; j++) if (b[j] === 0xff && b[j + 1] === 0xe1) return true;
  return !(b[b.length - 2] === 0xff && b[b.length - 1] === 0xd9);
}
