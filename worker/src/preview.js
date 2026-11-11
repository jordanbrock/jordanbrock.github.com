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
const NAMED = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " " };

const decode = (s) => s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
  if (e[0] === "#") {
    const code = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
    return code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : m;
  }
  return NAMED[e.toLowerCase()] ?? m;
});
const clean = (s, max) => decode(String(s ?? "")).replace(/\s+/g, " ").trim().slice(0, max);

// name/property (lowercased) => content, first one wins.
function metaTags(html) {
  const tags = {};
  for (const [tag] of html.matchAll(/<meta\b[^>]*>/gi)) {
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
