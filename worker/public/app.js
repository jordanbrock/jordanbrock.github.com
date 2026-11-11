// The posting page: tabs, preparing photos in the browser, and sending the
// post to /posts. Photos are resized to at most MAX_WIDTH and re-encoded as
// JPEG on a canvas, which drops all their metadata (including GPS).
import { stripApp1 } from "./jpeg.js";

const MAX_WIDTH = 2400; // the widest size the site makes
const MAX_POST_BYTES = 40 * 1024 * 1024; // the server's cap: MAX_POST_BYTES in src/validate.js
const KINDS = ["note", "link", "photos"];
const CONTENT_LABELS = { note: "Note", link: "Comment (optional)", photos: "Intro (optional)" };

const form = document.querySelector("#post");
const list = document.querySelector("#photos");
const picker = document.querySelector("#picker");
const status = document.querySelector("#status");
const submit = document.querySelector("#submit");
let photos = []; // [{ blob, url, alt, caption }] in post order

const kind = () => form.elements.kind.value;

function setKind(k) {
  form.elements.kind.value = k;
  for (const tab of form.querySelectorAll("[data-kind]")) tab.setAttribute("aria-pressed", String(tab.dataset.kind === k));
  render();
}

// Shows the fields for the current kind. Title is for links and albums; a
// single photo's caption is its text, so the intro is hidden then.
function render() {
  const k = kind();
  const album = k === "photos" && photos.length > 1;
  for (const el of form.querySelectorAll("[data-for]")) {
    el.hidden = el.dataset.for === "title" ? !(k === "link" || album) : el.dataset.for !== k;
  }
  form.querySelector("[data-content]").hidden = k === "photos" && photos.length === 1;
  document.querySelector("#content-label").textContent = CONTENT_LABELS[k];
}

async function toJpeg(file) {
  const src = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = src;
    await img.decode(); // browsers apply the EXIF orientation when decoding
    const scale = Math.min(1, MAX_WIDTH / img.naturalWidth);
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(img.naturalWidth * scale);
    canvas.height = Math.round(img.naturalHeight * scale);
    canvas.getContext("2d").drawImage(img, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.9));
    if (!blob) throw new Error("encode failed");
    // Some encoders may still write an EXIF/XMP segment, which the Worker refuses.
    const bytes = stripApp1(new Uint8Array(await blob.arrayBuffer()));
    return new Blob([bytes], { type: "image/jpeg" });
  } finally {
    URL.revokeObjectURL(src);
  }
}

function field(label, value, onInput) {
  const wrap = document.createElement("label");
  const input = document.createElement("input");
  input.value = value;
  input.autocomplete = "off";
  input.addEventListener("input", () => onInput(input.value));
  wrap.append(label, input);
  return wrap;
}

function button(text, label, enabled, onClick) {
  const b = document.createElement("button");
  Object.assign(b, { type: "button", textContent: text, disabled: !enabled });
  b.setAttribute("aria-label", label);
  b.addEventListener("click", onClick);
  return b;
}

function renderPhotos() {
  list.replaceChildren(...photos.map((p, i) => {
    const li = document.createElement("li");
    const thumb = document.createElement("img");
    Object.assign(thumb, { src: p.url, alt: "" });
    const tools = document.createElement("div");
    tools.className = "tools";
    tools.append(
      button("\u2191", `Move photo ${i + 1} up`, i > 0, () => move(i, -1)),
      button("\u2193", `Move photo ${i + 1} down`, i < photos.length - 1, () => move(i, 1)),
      button("Remove", `Remove photo ${i + 1}`, true, () => removePhoto(i)),
    );
    li.append(thumb, field("Alt text", p.alt, (v) => (p.alt = v)), field("Caption (optional)", p.caption, (v) => (p.caption = v)), tools);
    return li;
  }));
}

function move(i, by) {
  [photos[i], photos[i + by]] = [photos[i + by], photos[i]];
  renderPhotos();
}

function removePhoto(i) {
  URL.revokeObjectURL(photos[i].url);
  photos.splice(i, 1);
  renderPhotos();
  render();
}

picker.addEventListener("change", async () => {
  const files = [...picker.files];
  picker.value = "";
  const failed = [];
  status.textContent = `Preparing ${files.length} photo${files.length === 1 ? "" : "s"}\u2026`;
  for (const file of files) {
    try {
      const blob = await toJpeg(file);
      photos.push({ blob, url: URL.createObjectURL(blob), alt: "", caption: "" });
    } catch {
      failed.push(file.name);
    }
  }
  status.textContent = failed.length ? `Couldn't read ${failed.join(", ")}.` : "";
  renderPhotos();
  render();
});

function reset() {
  const k = kind();
  form.reset();
  photos.forEach((p) => URL.revokeObjectURL(p.url));
  photos = [];
  renderPhotos();
  setKind(k);
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = new FormData();
  for (const name of ["kind", "content", "url", "title", "tags"]) data.append(name, form.elements[name].value);
  if (kind() === "photos") {
    // Checked here too so a big album isn't uploaded only to be refused.
    if (photos.reduce((sum, p) => sum + p.blob.size, 0) > MAX_POST_BYTES) {
      status.textContent = "These photos add up to more than 40 MB. Post them in two goes.";
      return;
    }
    photos.forEach((p, i) => {
      data.append("photo", p.blob, `${String(i + 1).padStart(2, "0")}.jpg`);
      data.append("alt", p.alt);
      data.append("caption", p.caption);
    });
  }

  submit.disabled = true;
  status.textContent = "Posting\u2026";
  try {
    // An expired Access session answers with a redirect to the sign-in page.
    const res = await fetch("/posts", { method: "POST", body: data, redirect: "manual" });
    if (res.type === "opaqueredirect" || res.status === 401) {
      throw new Error("Your sign-in has expired. Copy anything you want to keep, then reload the page to sign in again.");
    }
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(body.error || `Posting failed (${res.status}).`);
    reset();
    const link = document.createElement("a");
    Object.assign(link, { href: body.url, textContent: body.url });
    status.replaceChildren("Posted. It'll be live in about two minutes: ", link);
  } catch (e) {
    status.textContent = e instanceof TypeError ? "Couldn't reach the server. Check your connection and try again." : e.message;
  } finally {
    submit.disabled = false;
  }
});

for (const tab of form.querySelectorAll("[data-kind]")) tab.addEventListener("click", () => setKind(tab.dataset.kind));
const params = new URLSearchParams(location.search);
form.elements.url.value = params.get("url") ?? "";
form.elements.title.value = params.get("title") ?? "";
setKind(KINDS.includes(params.get("tab")) ? params.get("tab") : "note");
