// The posting page: tabs, preparing photos in the browser, and sending the
// post to /posts. Photos are resized to at most MAX_WIDTH and re-encoded as
// JPEG by encode.js, which drops all their metadata (including GPS).
import { toJpeg } from "./encode.js";
import { setupPreview } from "./preview.js";

const MAX_WIDTH = 2400; // the widest size the site makes
const MAX_PHOTOS = 25; // the server's cap: MAX_PHOTOS in src/validate.js
const MAX_PHOTO_BYTES = 10 * 1024 * 1024; // the server's cap: MAX_PHOTO_BYTES in src/validate.js
const MAX_POST_BYTES = 40 * 1024 * 1024; // the server's cap: MAX_POST_BYTES in src/validate.js
const KINDS = ["note", "link", "photos"];
const CONTENT_LABELS = { note: "Note", link: "Comment (optional)", photos: "Intro (optional)" };
const FIELDS = ["kind", "content", "url", "title", "tags"];

const form = document.querySelector("#post");
const fields = document.querySelector("#fields");
const list = document.querySelector("#photos");
const picker = document.querySelector("#picker");
const status = document.querySelector("#status");
let photos = []; // [{ blob, url, alt, caption }] in post order
let preparing = false;
const preview = setupPreview(form);

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

function field(label, ariaLabel, value, onInput) {
  const wrap = document.createElement("label");
  const input = document.createElement("input");
  input.value = value;
  input.autocomplete = "off";
  input.setAttribute("aria-label", ariaLabel);
  input.addEventListener("input", () => onInput(input.value));
  wrap.append(label, input);
  return wrap;
}

function button(text, action, label, enabled, onClick) {
  const b = document.createElement("button");
  Object.assign(b, { type: "button", textContent: text, disabled: !enabled });
  b.dataset.action = action;
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
      button("\u2191", "up", `Move photo ${i + 1} up`, i > 0, () => move(i, -1, "up")),
      button("\u2193", "down", `Move photo ${i + 1} down`, i < photos.length - 1, () => move(i, 1, "down")),
      button("Remove", "remove", `Remove photo ${i + 1}`, true, () => removePhoto(i)),
    );
    li.append(
      thumb,
      field("Alt text", `Photo ${i + 1} alt text`, p.alt, (v) => (p.alt = v)),
      field("Caption (optional)", `Photo ${i + 1} caption`, p.caption, (v) => (p.caption = v)),
      tools,
    );
    return li;
  }));
}

const control = (i, action) => list.children[i]?.querySelector(`[data-action="${action}"]`);

// Keeps focus on the button that was pressed, now on the moved photo; if
// that button is disabled at the new place, the other arrow.
function move(i, by, action) {
  [photos[i], photos[i + by]] = [photos[i + by], photos[i]];
  renderPhotos();
  const j = i + by;
  const same = control(j, action);
  (same && !same.disabled ? same : control(j, action === "up" ? "down" : "up"))?.focus();
}

function removePhoto(i) {
  URL.revokeObjectURL(photos[i].url);
  photos.splice(i, 1);
  renderPhotos();
  render();
  (control(i, "remove") ?? picker).focus();
}

const failure = (name) => (/\.hei[cf]$/i.test(name) ? `${name} (HEIC isn't supported in this browser; try Safari.)` : name);

picker.addEventListener("change", async () => {
  const files = [...picker.files];
  picker.value = "";
  if (files.length === 0) return;
  const unreadable = [];
  const tooBig = [];
  preparing = true;
  fields.disabled = true;
  status.textContent = `Preparing ${files.length} photo${files.length === 1 ? "" : "s"}\u2026`;
  try {
    for (const file of files) {
      try {
        const blob = await toJpeg(file, MAX_WIDTH);
        if (blob.size > MAX_PHOTO_BYTES) {
          tooBig.push(`${file.name} is too big after resizing.`);
          continue;
        }
        photos.push({ blob, url: URL.createObjectURL(blob), alt: "", caption: "" });
      } catch {
        unreadable.push(failure(file.name));
      }
    }
  } finally {
    preparing = false;
    fields.disabled = false;
  }
  const messages = unreadable.length ? [`Couldn't read ${unreadable.join(", ")}.`, ...tooBig] : tooBig;
  status.textContent = messages.join(" ");
  renderPhotos();
  render();
});

function reset() {
  const k = kind();
  form.reset();
  preview.clear();
  photos.forEach((p) => URL.revokeObjectURL(p.url));
  photos = [];
  renderPhotos();
  setKind(k);
}

const isLink = (url) => typeof url === "string" && /^https?:\/\//i.test(url);

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (preparing) {
    status.textContent = "Still preparing photos\u2026";
    return;
  }
  if (kind() === "link" && preview.busy()) {
    status.textContent = "Still loading the preview\u2026";
    return;
  }

  // Built from each control's value (not new FormData(form)), so it works
  // while the fieldset is disabled. A field the page is hiding sends "".
  const data = new FormData();
  for (const name of FIELDS) {
    const el = form.elements[name];
    data.append(name, el.closest("[hidden]") ? "" : el.value);
  }
  if (kind() === "photos") {
    // Checked here too so a big album isn't uploaded only to be refused.
    if (photos.length > MAX_PHOTOS) {
      status.textContent = `At most ${MAX_PHOTOS} photos per post.`;
      return;
    }
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
  if (kind() === "link") preview.appendTo(data);

  fields.disabled = true;
  status.textContent = "Posting\u2026";
  try {
    // An expired Access session answers with a redirect to the sign-in page.
    const res = await fetch("/posts", { method: "POST", body: data, redirect: "manual" });
    if (res.type === "opaqueredirect" || res.status === 401) {
      throw new Error("Your sign-in has expired. Copy anything you want to keep, then reload the page to sign in again.");
    }
    const body = await res.json().catch(() => ({}));
    // 201 is a commit; 200 with dryRun is a local dry run. Anything else keeps the form.
    const dryRun = res.status === 200 && body.dryRun === true;
    if (res.status !== 201 && !dryRun) throw new Error(body.error || `Posting failed (${res.status}).`);
    reset();
    const prefix = dryRun ? "Dry run (nothing was committed)" : "Posted. It'll be live in about two minutes";
    if (isLink(body.url)) {
      const link = document.createElement("a");
      Object.assign(link, { href: body.url, textContent: body.url });
      status.replaceChildren(`${prefix}: `, link);
    } else {
      status.textContent = dryRun ? `${prefix}.` : "Posted.";
    }
  } catch (e) {
    status.textContent = e instanceof TypeError ? "Couldn't reach the server. Check your connection and try again." : e.message;
  } finally {
    fields.disabled = false;
  }
});

for (const tab of form.querySelectorAll("[data-kind]")) tab.addEventListener("click", () => setKind(tab.dataset.kind));
const params = new URLSearchParams(location.search);
form.elements.url.value = params.get("url") ?? "";
form.elements.title.value = params.get("title") ?? "";
setKind(KINDS.includes(params.get("tab")) ? params.get("tab") : "note");
if (form.elements.url.value) preview.load(form.elements.url.value.trim());
if (location.search) history.replaceState(null, "", location.pathname);
