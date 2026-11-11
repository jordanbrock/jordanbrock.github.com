// The Link tab's preview card: asks the Worker for the link's sharing tags,
// shows them, and prepares the preview image like a photo (re-encoded as
// JPEG on a canvas, metadata stripped) so it can be posted with the link.
// Everything in the card comes from another site, so it's only ever set as
// text or properties, never as HTML.
import { toJpeg } from "./encode.js";

const MAX_WIDTH = 1200;
const WAIT_MS = 600; // after typing stops

export function setupPreview(form) {
  const $ = (id) => document.getElementById(id);
  const card = $("preview");
  const image = $("preview-image");
  const site = $("preview-site");
  const title = $("preview-title");
  const description = $("preview-description");
  const include = $("preview-include");
  const includeLabel = include.closest("label"); // shown only when there is an image to include
  const note = $("preview-status");
  let current = null; // { title, description, site, blob }
  let requested = null; // the URL last looked up, so blurring the field doesn't look it up again
  let imageUrl = null;
  let seq = 0;
  let loading = false;
  let timer;

  function clear() {
    clearTimeout(timer);
    seq++;
    loading = false;
    current = null;
    requested = null;
    card.hidden = true;
    image.hidden = true;
    image.removeAttribute("src");
    if (imageUrl) URL.revokeObjectURL(imageUrl);
    imageUrl = null;
    include.checked = true;
    includeLabel.hidden = true;
    note.textContent = "";
  }

  async function load(url) {
    clear();
    requested = url;
    if (!/^https?:\/\/\S+\.\S+/i.test(url)) return;
    const mine = seq;
    loading = true;
    note.textContent = "Looking for a preview\u2026";
    try {
      const res = await fetch(`/preview?url=${encodeURIComponent(url)}`, { redirect: "manual" });
      const body = await res.json().catch(() => ({}));
      if (mine !== seq) return;
      if (!res.ok || !(body.title || body.description || body.image)) {
        note.textContent = res.ok ? "No preview found. You can still post the link." : (body.error || "Couldn't get a preview.");
        return;
      }
      current = { title: body.title ?? "", description: body.description ?? "", site: body.site ?? "", blob: null };
      site.textContent = current.site;
      title.textContent = current.title;
      description.textContent = current.description;
      card.hidden = false;
      if (!form.elements.title.value.trim() && current.title) form.elements.title.value = current.title;
      note.textContent = "";
      if (body.image) {
        note.textContent = "Loading the preview image\u2026";
        const img = await fetch(`/preview/image?url=${encodeURIComponent(body.image)}`, { redirect: "manual" });
        if (mine !== seq) return;
        if (!img.ok) throw new Error("image");
        const blob = await toJpeg(await img.blob(), MAX_WIDTH);
        if (mine !== seq) return;
        current.blob = blob;
        imageUrl = URL.createObjectURL(blob);
        image.src = imageUrl;
        image.hidden = false;
        includeLabel.hidden = false;
        note.textContent = "";
      }
    } catch {
      if (mine === seq) note.textContent = current ? "Couldn't load the preview image; the link will post without it." : "Couldn't get a preview.";
    } finally {
      if (mine === seq) loading = false;
    }
  }

  const url = form.elements.url;
  url.addEventListener("input", () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      if (url.value.trim() !== requested) load(url.value.trim());
    }, WAIT_MS);
  });
  url.addEventListener("change", () => {
    clearTimeout(timer);
    if (url.value.trim() !== requested) load(url.value.trim());
  });
  $("preview-use-title").addEventListener("click", () => {
    if (current?.title) form.elements.title.value = current.title;
  });

  return {
    load,
    clear,
    busy: () => loading,
    // Appends the preview to a link post's form data.
    appendTo(data) {
      if (!current) return;
      data.append("preview_title", current.title);
      data.append("preview_description", current.description);
      data.append("preview_site", current.site);
      if (current.blob && include.checked) data.append("preview_image", current.blob, "preview.jpg");
    },
  };
}
