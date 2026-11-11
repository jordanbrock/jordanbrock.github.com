// The posting Worker. The page itself is a static asset (public/); this
// handles POST /posts: check Access, read and validate the form, pick a free
// file name, and commit the post and its photos in one commit.
import { verifyAccess } from "./access.js";
import { parseForm } from "./form.js";
import { github as makeGitHub } from "./github.js";
import { buildPost } from "./post.js";
import { ValidationError, validate } from "./validate.js";

const MAX_SLUG_TRIES = 5; // each try costs up to 2 GitHub subrequests; the Free plan allows 50 per request
const json = (body, status) => Response.json(body, { status });

export default {
  fetch: (request, env) => handle(request, env),
};

// deps lets tests pass a key set, a fake GitHub and a fixed clock.
export async function handle(request, env, deps = {}) {
  const url = new URL(request.url);
  if (url.pathname !== "/posts") return new Response("Not found", { status: 404 });
  if (request.method !== "POST") return json({ error: "Use POST." }, 405);
  if (request.headers.get("Origin") !== url.origin) return json({ error: "Posts must come from the posting page." }, 403);

  try {
    await verifyAccess(request, env, deps.keySet);
  } catch (e) {
    console.warn("access:", e.message); // AccessError messages never contain the token
    return json({ error: "You're not signed in. Reload the page to sign in again." }, 401);
  }

  // The form is read straight into input, so only input (and later post and
  // files, which share its byte arrays) hold the photos: no copies.
  let input;
  try {
    input = await parseForm(await request.formData());
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
    if (dryRun) return json({ url: post.url, path: post.path, markdown: post.markdown, files: files.map((f) => f.path) }, 200);

    await gh.commit(files, `Post: ${post.slug}`, { name: env.AUTHOR_NAME, email: env.AUTHOR_EMAIL });
    return json({ url: post.url, path: post.path }, 201);
  } catch (e) {
    return json({ error: `Couldn't save the post: ${e.message}` }, 502);
  }
}

// The post with the first free slug: neither its file nor its photos' place
// exists. An album's place is its folder (hand-made albums use names like
// 01-frogmouth.jpg, so checking 01.jpg would miss them); a single photo's is
// its file.
async function freePost(input, now, gh) {
  for (let n = 1; n <= MAX_SLUG_TRIES; n++) {
    const post = buildPost(input, now, n);
    if (await gh.exists(post.path)) continue;
    if (post.photos.length > 0 && (await gh.exists(photoPlace(post.photos)))) continue;
    return post;
  }
  return null;
}

const photoPlace = (photos) => (photos.length > 1 ? photos[0].path.slice(0, photos[0].path.lastIndexOf("/")) : photos[0].path);
