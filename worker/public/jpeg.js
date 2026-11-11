// Removes APP1 segments (EXIF or XMP) from a JPEG's header. A canvas
// re-encode shouldn't write any, but some browsers' encoders may, and the
// Worker refuses any JPEG with APP1. This is a safety net: if the bytes
// aren't laid out as expected, they come back unchanged and the server
// decides.
export function stripApp1(bytes) {
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
    if (m === 0xe1) removed = true;
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
