// Opens a stream photo (a.lightbox) full screen and uncropped, in a <dialog>.
// Without JavaScript, or with a modifier key held, the link goes to the post.
document.addEventListener("click", (event) => {
  const link = event.target.closest("a.lightbox");
  if (!link || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  event.preventDefault();

  const picture = link.querySelector("picture").cloneNode(true);
  picture.querySelectorAll("source, img").forEach((el) => el.setAttribute("sizes", "100vw"));
  const img = picture.querySelector("img");
  img.removeAttribute("loading");

  const close = document.createElement("button");
  close.type = "button";
  close.textContent = "Close";

  const dialog = document.createElement("dialog");
  dialog.className = "lightbox-dialog";
  dialog.setAttribute("aria-label", img.alt);
  dialog.append(picture, close);
  dialog.addEventListener("click", () => dialog.close()); // the photo, the button or the backdrop
  dialog.addEventListener("close", () => { dialog.remove(); link.focus(); });
  document.body.append(dialog);
  dialog.showModal();
  close.focus();
});
