// The posting Worker. The page itself is a static asset (public/); this
// handles POST /posts: check Access, read and validate the form, pick a free
// file name, and commit the post and its photos in one commit.
import { AccessConfigError, verifyAccess } from "./access.js";
import { parseForm } from "./form.js";
import { GitHubError, SlugTakenError, github as makeGitHub } from "./github.js";
import { buildPost } from "./post.js";
import { MAX_POST_BYTES, TOO_BIG, ValidationError, validate } from "./validate.js";

// The Workers Free plan allows 50 subrequests per request. Worst case:
// 1 JWKS fetch + 3 tries x 2 exists + 26 blobs (25 photos + the post)
// + 2 commit attempts x (5 Git calls + 2 mustBeNew checks) = 47.
const MAX_SLUG_TRIES = 3;
const FORM_OVERHEAD = 1024 * 1024; // text fields and multipart boundaries
const json = (body, status) => Response.json(body, { status });

export default {
  fetch: (request, env) => handle(request, env),
};

// deps lets tests pass a key set, a fake GitHub and a fixed clock.
export async function handle(request, env, deps = {}) {
  const url = new URL(request.url);
  if (url.pathname !== "/posts") return new Response("Not found", { status: 404 });
  if (request.method !== "POST") return json({ error: "Use POST." }, 405);
  if (request.headers.get("Origin") !== url.origin) {
    console.warn("origin:", request.headers.get("Origin"));
    return json({ error: "Posts must come from the posting page." }, 403);
  }

  try {
    await verifyAccess(request, env, deps.keySet);
  } catch (e) {
    console.warn("access:", e.message); // AccessError messages never contain the token
    if (e instanceof AccessConfigError) return json({ error: "Posting isn't set up properly. Check the Worker's Access settings." }, 503);
    return json({ error: "You're not signed in. Reload the page to sign in again." }, 401);
  }

  // Browsers send a Content-Length with a form; without one the size can't be
  // checked before the body is read.
  const length = request.headers.get("Content-Length");
  if (length === null) return json({ error: "Length required." }, 411);
  if (Number(length) > MAX_POST_BYTES + FORM_OVERHEAD) return json({ error: TOO_BIG }, 413);

  let form;
  try {
    form = await request.formData();
  } catch {
    return json({ error: "That didn't arrive as a form. Reload the page and try again." }, 400);
  }

  // The form is read straight into input, so only input (and later post and
  // files, which share its byte arrays) hold the photos: no copies.
  let input;
  try {
    input = await parseForm(form);
    form = null;
    validate(input);
  } catch (e) {
    if (e instanceof ValidationError) return json({ error: e.message }, 422);
    throw e;
  }

  const dryRun = env.DRY_RUN === "1";
  const gh = deps.github ?? (dryRun ? { exists: async () => false } : makeGitHub(env));
  try {
    const post = await freePost(input, deps.now ?? new Date(), gh);
    if (!post) return json({ error: "Couldn't find a free file name for this post." }, 409);

    const files = [{ path: post.path, content: post.markdown }, ...post.photos.map((p) => ({ path: p.path, content: p.bytes }))];
    if (dryRun) return json({ dryRun: true, url: post.url, path: post.path, markdown: post.markdown, files: files.map((f) => f.path) }, 200);

    // Checked again at the commit's parent: another post may take the name
    // while the photos upload.
    const mustBeNew = [post.path, photoPlace(post.photos)].filter(Boolean);
    await gh.commit(files, `Post: ${post.slug}`, { name: env.AUTHOR_NAME, email: env.AUTHOR_EMAIL }, { mustBeNew });
    return json({ url: post.url, path: post.path }, 201);
  } catch (e) {
    if (e instanceof SlugTakenError) return json({ error: "Another post just took this name. Post again." }, 409);
    if (e instanceof GitHubError) return json({ error: `Couldn't save the post: ${e.message}` }, 502);
    console.error("post:", e);
    return json({ error: "Something went wrong saving the post." }, 500);
  }
}

// The post with the first free slug: neither its file nor its photos' place
// exists.
async function freePost(input, now, gh) {
  for (let n = 1; n <= MAX_SLUG_TRIES; n++) {
    const post = buildPost(input, now, n);
    if (await gh.exists(post.path)) continue;
    if (post.photos.length > 0 && (await gh.exists(photoPlace(post.photos)))) continue;
    return post;
  }
  return null;
}

// Where a post's photos go: an album's folder (hand-made albums use names
// like 01-frogmouth.jpg, so checking 01.jpg would miss them), or a single
// photo's file. Undefined for a post without photos.
function photoPlace(photos) {
  if (photos.length === 0) return undefined;
  const first = photos[0].path;
  return photos.length > 1 ? first.slice(0, first.lastIndexOf("/")) : first;
}
