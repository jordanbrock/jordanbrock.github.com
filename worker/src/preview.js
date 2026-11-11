// Link previews: reads a page's sharing tags (Open Graph, then Twitter, then
// <title> and the meta description) and fetches its preview image for the
// posting page. Plain string parsing, so it runs (and is tested) outside the
// Workers runtime.

export class PreviewError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

const LIMITS = { title: 300, description: 500, site: 100 };
const NAMED = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ",
  rsquo: "\u2019", lsquo: "\u2018", ldquo: "\u201c", rdquo: "\u201d", mdash: "\u2014", ndash: "\u2013",
  hellip: "\u2026", copy: "\u00a9", reg: "\u00ae", trade: "\u2122", middot: "\u00b7",
};

const decode = (s) => s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
  if (e[0] === "#") {
    const code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
    return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : m;
  }
  return NAMED[e.toLowerCase()] ?? m;
});
const clean = (s, max) => decode(String(s ?? "")).replace(/\s+/g, " ").trim().slice(0, max);

// name/property (lowercased) => content, first one wins.
function metaTags(html) {
  const tags = {};
  for (const [tag] of html.matchAll(/<meta\b(?:[^>"']|"[^"]*"|'[^']*')*>/gi)) {
    const attrs = {};
    for (const m of tag.matchAll(/([a-z_:.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/gi)) {
      attrs[m[1].toLowerCase()] = m[2] ?? m[3] ?? m[4];
    }
    const key = (attrs.property ?? attrs.name ?? "").toLowerCase();
    if (key && attrs.content !== undefined && !(key in tags)) tags[key] = attrs.content;
  }
  return tags;
}

function absoluteImage(src, pageUrl) {
  if (!src) return "";
  try {
    const url = new URL(decode(src.trim()), pageUrl);
    return url.protocol === "http:" || url.protocol === "https:" ? url.href : "";
  } catch {
    return "";
  }
}

export function parsePreview(html, pageUrl) {
  const tags = metaTags(html);
  const first = (...keys) => keys.map((k) => tags[k]).find((v) => v && v.trim());
  const title = first("og:title", "twitter:title") ?? html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)?.[1];
  return {
    title: clean(title, LIMITS.title),
    description: clean(first("og:description", "twitter:description", "description"), LIMITS.description),
    site: clean(first("og:site_name"), LIMITS.site),
    image: absoluteImage(first("og:image", "og:image:url", "og:image:secure_url", "twitter:image", "twitter:image:src"), pageUrl),
  };
}

const HTML_BYTES = 1024 * 1024; // the tags are in <head>; stop reading after this
const IMAGE_BYTES = 5 * 1024 * 1024;
const TIMEOUT_MS = 5000;
// Generic on purpose: never name the site's owner to other sites.
const HEADERS = { "User-Agent": "Mozilla/5.0 (compatible; LinkPreview/1.0)" };

// Only public http(s) hosts: no localhost or IP literals. Redirects aren't
// re-checked: deployed Workers can't reach private networks anyway, so this
// check is for clear error messages.
function target(raw) {
  let url;
  try { url = new URL(String(raw ?? "").trim()); } catch { throw new PreviewError("That isn't a valid URL.", 422); }
  const host = url.hostname.toLowerCase();
  const literal = /^\d{1,3}(\.\d{1,3}){3}$/.test(host) || host.startsWith("[");
  if (!["http:", "https:"].includes(url.protocol) || !host || host === "localhost" || host.endsWith(".localhost") || literal) {
    throw new PreviewError("Previews only work for public http:// or https:// links.", 422);
  }
  return url.href;
}

async function get(url, accept, fetchImpl) {
  let res;
  try {
    res = await fetchImpl(url, { headers: { ...HEADERS, Accept: accept }, redirect: "follow", signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch {
    throw new PreviewError("Couldn't reach that page.", 502);
  }
  if (!res.ok) {
    await res.body?.cancel();
    throw new PreviewError(`That page answered ${res.status}.`, 502);
  }
  return res;
}

// Up to max bytes of the body. With truncate, stops quietly at max;
// otherwise a longer body is an error.
async function read(res, max, truncate) {
  const chunks = [];
  let total = 0;
  const reader = res.body.getReader();
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > max) {
        await reader.cancel();
        if (!truncate) throw new PreviewError("That image is over 5 MB.", 422);
        chunks.push(value.subarray(0, value.length - (total - max)));
        total = max;
        break;
      }
      chunks.push(value);
    }
  } catch (e) {
    if (e instanceof PreviewError) throw e;
    throw new PreviewError("That page took too long or stopped answering.", 502); // timeout or reset mid-body
  }
  const bytes = new Uint8Array(total);
  let at = 0;
  for (const c of chunks) { bytes.set(c, at); at += c.length; }
  return bytes;
}

// UTF-8 unless Content-Type names a charset the runtime knows.
function decodeBody(bytes, contentType) {
  const label = /charset\s*=\s*["']?([^\s;"']+)/i.exec(contentType)?.[1];
  try {
    return new TextDecoder(label || "utf-8").decode(bytes);
  } catch {
    return new TextDecoder().decode(bytes);
  }
}

export async function fetchPreview(raw, fetchImpl = fetch) {
  const url = target(raw);
  const res = await get(url, "text/html,application/xhtml+xml", fetchImpl);
  const type = res.headers.get("Content-Type") ?? "";
  if (/^\s*image\//i.test(type)) {
    await res.body?.cancel();
    return { ...parsePreview("", url), image: res.url || url };
  }
  if (!/html/i.test(type)) {
    await res.body?.cancel();
    return parsePreview("", url);
  }
  const html = decodeBody(await read(res, HTML_BYTES, true), type);
  return parsePreview(html, res.url || url);
}

function imageType(b) {
  if (b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return "image/jpeg";
  if (b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return "image/png";
  if (b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x38) return "image/gif";
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 && b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) return "image/webp";
  return null;
}

// The image's bytes and type, sniffed from the bytes (never trusted from the
// other site's Content-Type, and never SVG, which can carry script).
export async function fetchPreviewImage(raw, fetchImpl = fetch) {
  const url = target(raw);
  const res = await get(url, "image/*", fetchImpl);
  const bytes = await read(res, IMAGE_BYTES, false);
  const type = imageType(bytes);
  if (!type) throw new PreviewError("That isn't an image.", 422);
  return { bytes, type };
}
