// Removes metadata segments from a JPEG's header: every APPn and COM except
// JFIF (APP0), ICC colour (APP2) and Adobe (APP14), the ones the Worker
// allows (ALLOWED_APP in src/validate.js; keep the two in step). A canvas
// re-encode shouldn't write others, but some browsers' encoders may write
// EXIF. This is a safety net: if the bytes aren't laid out as expected, they
// come back unchanged and the server decides.
const ALLOWED_APP = { 0xe0: "JFIF\0", 0xe2: "ICC_PROFILE\0", 0xee: "Adobe" };

function isMetadata(b, i, m, len) {
  if (m !== 0xfe && (m < 0xe0 || m > 0xef)) return false; // not APPn or COM
  const signature = ALLOWED_APP[m];
  if (!signature || len - 2 < signature.length) return true;
  return ![...signature].every((c, k) => b[i + 4 + k] === c.charCodeAt(0));
}

export function stripMetadata(bytes) {
  const b = bytes;
  if (b.length < 4 || b[0] !== 0xff || b[1] !== 0xd8) return bytes;
  const keep = [b.subarray(0, 2)]; // SOI
  let i = 2;
  let removed = false;
  for (;;) {
    if (i + 3 >= b.length || b[i] !== 0xff) return bytes;
    const m = b[i + 1];
    if (m === 0xda) break; // start of scan: the rest is copied as is
    // A marker with no length (or a fill byte) has no place in the header.
    if (m === 0x00 || m === 0x01 || m === 0xff || (m >= 0xd0 && m <= 0xd9)) return bytes;
    const len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2 || i + 2 + len > b.length) return bytes;
    if (isMetadata(b, i, m, len)) removed = true;
    else keep.push(b.subarray(i, i + 2 + len));
    i += 2 + len;
  }
  if (!removed) return bytes;
  keep.push(b.subarray(i));
  const out = new Uint8Array(keep.reduce((n, part) => n + part.length, 0));
  let at = 0;
  for (const part of keep) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}
