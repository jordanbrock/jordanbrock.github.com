// Re-encodes an image as JPEG on a canvas, at most maxWidth wide. Drawing on
// a canvas drops all metadata (including GPS); stripMetadata removes anything
// an encoder still writes, which the Worker would refuse.
import { stripMetadata } from "./jpeg.js";

export async function toJpeg(blob, maxWidth) {
  const src = URL.createObjectURL(blob);
  const canvas = document.createElement("canvas");
  try {
    const img = new Image();
    img.src = src;
    await img.decode(); // browsers apply the EXIF orientation when decoding
    const scale = Math.min(1, maxWidth / img.naturalWidth);
    canvas.width = Math.round(img.naturalWidth * scale);
    canvas.height = Math.round(img.naturalHeight * scale);
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("This browser couldn't make a canvas to resize the photo.");
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    const out = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.9));
    if (!out) throw new Error("encode failed");
    return new Blob([stripMetadata(new Uint8Array(await out.arrayBuffer()))], { type: "image/jpeg" });
  } finally {
    URL.revokeObjectURL(src);
    canvas.width = canvas.height = 0; // iOS holds canvas memory until it's shrunk
  }
}
