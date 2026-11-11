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

  const previewImage = input.preview?.bytes;
  if (previewImage) {
    if (previewImage.length > MAX_PHOTO_BYTES) fail("The preview image is over 10 MB.");
    if (!isJpeg(previewImage)) fail("The preview image isn't a JPEG.");
    if (unsafeJpeg(previewImage)) fail("The preview image has metadata or isn't a clean JPEG. Look up the preview again.");
  }
}

export const isJpeg = (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

// Application segments allowed, by marker: the payload must start with the
// given signature. Any other APPn, and COM, may carry camera data.
const ALLOWED_APP = { 0xe0: "JFIF\0", 0xe2: "ICC_PROFILE\0", 0xee: "Adobe" };
const TABLES = [0xc4, 0xcc, 0xdb, 0xdd]; // DHT, DAC, DQT, DRI
const isFrame = (m) => m >= 0xc0 && m <= 0xcf && !TABLES.includes(m) && m !== 0xc8; // SOFn

const startsWith = (b, at, text) => [...text].every((c, k) => b[at + k] === c.charCodeAt(0));

// The index of the marker that ends the entropy-coded data starting at j.
// In that data FF is stuffed as FF00, and RSTn markers sit inline.
function endOfScan(b, j) {
  for (; j + 1 < b.length; j++) {
    if (b[j] !== 0xff) continue;
    const n = b[j + 1];
    if (n === 0x00 || n === 0xff || (n >= 0xd0 && n <= 0xd7)) continue;
    return j;
  }
  return b.length;
}

// True unless the JPEG is a clean, well-formed run of segments: SOI, then
// tables, one frame (SOFn) and scans (SOS + entropy data), with only JFIF,
// ICC colour and Adobe application segments anywhere, and EOI as the last two
// bytes. Anything else is refused (an allowlist), because libjpeg is more
// forgiving than this walk and could still find camera data we skipped.
export function unsafeJpeg(b) {
  if (!isJpeg(b)) return true;
  let i = 2;
  let frame = false;
  let scanned = false;
  for (;;) {
    if (i + 1 >= b.length || b[i] !== 0xff) return true;
    while (i + 1 < b.length && b[i + 1] === 0xff) i++; // fill bytes
    if (i + 1 >= b.length) return true;
    const m = b[i + 1];
    if (m === 0xd9) return !(scanned && i + 2 === b.length); // EOI must end the file
    if (i + 3 >= b.length) return true;
    const len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2 || i + 2 + len > b.length) return true;
    const next = i + 2 + len;
    if (m === 0xda) {
      if (!frame) return true;
      scanned = true;
      i = endOfScan(b, next);
      continue;
    }
    if (isFrame(m)) {
      if (frame || len < 11) return true; // second frame, or too short for 8 bytes + a component
      const height = (b[i + 5] << 8) | b[i + 6];
      const width = (b[i + 7] << 8) | b[i + 8];
      if (!height || !width) return true;
      frame = true;
    } else if (!TABLES.includes(m)) {
      const signature = ALLOWED_APP[m];
      if (!signature || len - 2 < signature.length || !startsWith(b, i + 4, signature)) return true;
    }
    i = next;
  }
}
