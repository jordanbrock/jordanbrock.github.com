// Turns posting input into the files for one post. Pure (no I/O), so it is
// easy to test. The front matter follows the site's README ("Writing posts").

const ZONE = "Australia/Perth"; // no daylight saving: always +0800
const SITE = "https://jordanbrock.com";
const SLUG_WORDS = 6;

// The Perth date ("2026-11-11"), time ("14:03:09") and year of a moment.
export function perthParts(now) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONE, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
  }).formatToParts(now);
  const p = Object.fromEntries(parts.map((x) => [x.type, x.value]));
  return { date: `${p.year}-${p.month}-${p.day}`, time: `${p.hour}:${p.minute}:${p.second}`, year: p.year };
}

// Up to six lowercase ASCII words joined by hyphens, ignoring URLs.
export function slugify(text, fallback) {
  const words = String(text ?? "")
    .replace(/https?:\/\/\S+/g, " ")
    .normalize("NFKD").replace(/[̀-ͯ]/g, "")
    .toLowerCase().replace(/[^a-z0-9]+/g, " ")
    .trim().split(" ").filter(Boolean);
  return words.slice(0, SLUG_WORDS).join("-") || fallback;
}

const text = (s) => String(s ?? "").replace(/\r\n?/g, "\n").trim(); // keeps paragraphs
const line = (s) => text(s).replace(/\s+/g, " "); // one line, for front matter
const quote = (s) => JSON.stringify(s); // a JSON string is a valid YAML double-quoted string

// YAML front matter. Empty values are left out; every string is quoted.
function frontMatter(fields) {
  const lines = ["---"];
  for (const [key, value] of Object.entries(fields)) {
    if (value === undefined || value === "" || (Array.isArray(value) && value.length === 0)) continue;
    if (key === "photos") {
      lines.push("photos:");
      for (const photo of value) {
        lines.push(`  - image: ${quote(photo.image)}`, `    alt: ${quote(photo.alt)}`);
        if (photo.caption) lines.push(`    caption: ${quote(photo.caption)}`);
      }
    } else if (Array.isArray(value)) {
      lines.push(`${key}: [${value.map(quote).join(", ")}]`);
    } else {
      lines.push(`${key}: ${quote(value)}`);
    }
  }
  lines.push("---");
  return `${lines.join("\n")}\n`;
}

// The post for validated input. n > 1 appends "-n" to the slug (used when
// the plain slug is taken).
export function buildPost(input, now, n = 1) {
  const { date, time, year } = perthParts(now);
  const title = line(input.title);
  const single = input.kind === "photos" && input.photos.length === 1;
  const fields = { date: `${date} ${time} +0800` };
  let body = text(input.content);
  let slug;

  if (input.kind === "note") {
    slug = slugify(body, "note");
  } else if (input.kind === "link") {
    const url = line(input.url);
    slug = slugify(title || new URL(url).hostname.replace(/^www\./, ""), "link");
    Object.assign(fields, { title, link: url });
  } else if (single) {
    body = text(input.photos[0].caption) || body;
    slug = slugify(body, "photo");
  } else {
    slug = slugify(title || body, "album");
    fields.title = title;
  }
  if (n > 1) slug += `-${n}`;

  const photos = input.kind === "photos" ? input.photos.map((p, i) => ({
    image: single ? `${year}/${slug}.jpg` : `${year}/${slug}/${String(i + 1).padStart(2, "0")}.jpg`,
    alt: line(p.alt),
    caption: line(p.caption),
    bytes: p.bytes,
  })) : [];
  if (single) Object.assign(fields, { image: photos[0].image, alt: photos[0].alt });
  else if (photos.length) fields.photos = photos.map(({ image, alt, caption }) => ({ image, alt, caption }));
  fields.tags = input.tags.map(line).filter(Boolean);

  return {
    slug,
    path: `src/_posts/${date}-${slug}.md`,
    url: `${SITE}/${date.replaceAll("-", "/")}/${slug}/`,
    markdown: frontMatter(fields) + (body ? `${body}\n` : ""),
    photos: photos.map((p) => ({ path: `src/photos/${p.image}`, bytes: p.bytes })),
  };
}
