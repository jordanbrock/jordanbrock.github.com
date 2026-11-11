# Posting page

`post.jordanbrock.com` posts notes, links, photos and albums to the site from a phone or browser. Each post is one commit to master; the site's CI tests and deploys it in about two minutes.

- The page (`public/`) is a static asset of this Cloudflare Worker.
- `POST /posts` (`src/index.js`) checks the Cloudflare Access token, validates the post against the site's rules, and commits the Markdown file and photos to master in one commit through the GitHub API. If the name is taken it adds `-2`, `-3`; if master moves mid-commit it retries once.
- Photos are resized to 2400px wide and re-encoded as JPEG in the browser, which removes GPS and all other metadata. The Worker refuses any JPEG with metadata other than JFIF, ICC colour or Adobe segments. The repo is public, so this is the only GPS check before a photo is published.
- Link posts include the linked page's sharing preview (its Open Graph tags). The page asks `GET /preview` for the tags and `GET /preview/image` for the image, which the Worker fetches (public http(s) only, 5 s, 1 MB of HTML, 5 MB images) and serves from its own origin. The page re-encodes the image like a photo, at most 1200px wide, and it's committed as `src/photos/YYYY/<slug>-preview.jpg`.
- Limits: 25 photos and 40 MB per post, 10 MB per photo.
- The Worker only checks for the exact `.md` and `.jpg` names it writes (or an album's folder). A hand-added file with the same name but another extension, such as `2026/heron.png` next to a posted `2026/heron.jpg`, would clash in the build.

## Setup (once)

Do these in order, so the page is never reachable without Access.

1. **GitHub token.** In GitHub, go to Settings > Developer settings > Fine-grained tokens. Create a token for `jordanbrock/jordanbrock.github.com` only, with **Contents: Read and write**, and an expiry you're happy with.
2. **Cloudflare Access.** In Zero Trust, go to Access controls > Applications > Add an application > Self-hosted. (If this is your first visit, Zero Trust asks you to pick a team name first.)
   - Application domain: `post.jordanbrock.com`.
   - Policy: Allow, with Include set to Emails and your address.
   - After saving, edit the application and copy the **Application Audience (AUD) Tag** from **Additional settings**.
   - Your team domain is under Zero Trust > Settings > Team name and domain. Use it with `https://` in front: `https://<team>.cloudflareaccess.com`.
3. **Secrets.** Run each of these in `worker/` and paste the value when asked:

   ```bash
   npx wrangler login
   npx wrangler secret put GITHUB_TOKEN
   npx wrangler secret put ACCESS_TEAM_DOMAIN   # https://<team>.cloudflareaccess.com
   npx wrangler secret put ACCESS_AUD           # the AUD tag
   npx wrangler secret put ALLOWED_EMAIL        # the email in the Access policy
   npx wrangler secret put AUTHOR_NAME          # commit author name
   npx wrangler secret put AUTHOR_EMAIL         # commit author email
   ```

4. **Deploy:** `npm run deploy`. This creates the `post.jordanbrock.com` custom domain from `wrangler.toml`. The `workers.dev` address is turned off, so the Worker is only reachable through Access.
5. **Test it:** visit `https://post.jordanbrock.com/`, sign in, and post a note.

Even if Access were misconfigured, the Worker checks the Access token itself and refuses requests without a valid one for `ALLOWED_EMAIL`.

### Workers plan limits

- **CPU:** the Free plan allows 10 ms of CPU per request. Encoding photos for GitHub takes CPU time, so a large album may fail with a CPU-limit error. The Workers Paid plan raises the limit.
- **Subrequests:** the Free plan allows 50 per request. A post makes at most about 47 (25 photo uploads plus the name checks and commit), which is why posts are capped at 25 photos.

## Sharing links

**iPhone (Shortcuts app).** New shortcut > Details > **Show in Share Sheet**, receiving **URLs** and **Safari web pages**. Then add these actions:

1. **Get Details of Safari Web Page**: Name (of Shortcut Input)
2. **URL Encode**: Shortcut Input
3. **URL Encode**: Name
4. **Text**: `https://post.jordanbrock.com/?tab=link&url=` *URL Encoded Text (step 2)* `&title=` *URL Encoded Text (step 3)*
5. **Open URLs**: Text

Name it "Post link". In Safari, tap Share > Post link.

**Mac bookmarklet.** Make a bookmark with this as its address:

```
javascript:window.open('https://post.jordanbrock.com/?tab=link&url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title))
```

## Local development

```bash
npm install
cp .dev.vars.example .dev.vars   # skips Access on localhost; dry run, nothing is committed
npm run dev                      # http://localhost:8787
npm test
```

`npm run dev` runs `wrangler dev --local-upstream localhost:8787`, so the Access skip (localhost only) still applies even though `wrangler.toml` routes to the custom domain. With `DRY_RUN=1`, posting returns the Markdown and file paths it would commit.
