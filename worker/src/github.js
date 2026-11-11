// Commits files to the site's repo in a single commit, using the GitHub Git
// Data API (blobs -> tree -> commit -> move the branch).

export class GitHubError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

export function toBase64(bytes) {
  if (typeof bytes.toBase64 === "function") return bytes.toBase64();
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

export function github(env, fetchImpl = fetch) {
  const branch = env.GITHUB_BRANCH;

  const api = (method, path, body) => fetchImpl(`https://api.github.com/repos/${env.GITHUB_REPO}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "jordanbrock-post",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const ok = async (res, what) => {
    if (!res.ok) throw new GitHubError(`GitHub ${what} failed (${res.status})`, res.status);
    return res.json();
  };

  // Whether a file or directory exists on the branch.
  async function exists(path) {
    const encoded = path.split("/").map(encodeURIComponent).join("/");
    const res = await api("GET", `/contents/${encoded}?ref=${encodeURIComponent(branch)}`);
    if (res.status === 404) return false;
    if (!res.ok) throw new GitHubError(`GitHub lookup failed (${res.status})`, res.status);
    return true;
  }

  // files: [{ path, content: string | Uint8Array }]. Resolves to the new commit's sha.
  async function commit(files, message, author) {
    const tree = [];
    for (const file of files) {
      const bytes = typeof file.content === "string" ? new TextEncoder().encode(file.content) : file.content;
      const blob = await ok(await api("POST", "/git/blobs", { content: toBase64(bytes), encoding: "base64" }), "blob");
      tree.push({ path: file.path, mode: "100644", type: "blob", sha: blob.sha });
    }

    for (let attempt = 1; ; attempt++) {
      const ref = await ok(await api("GET", `/git/ref/heads/${branch}`), "branch lookup");
      const parent = await ok(await api("GET", `/git/commits/${ref.object.sha}`), "commit lookup");
      const newTree = await ok(await api("POST", "/git/trees", { base_tree: parent.tree.sha, tree }), "tree");
      const created = await ok(await api("POST", "/git/commits", {
        message, tree: newTree.sha, parents: [ref.object.sha],
        author: author?.name && author?.email ? author : undefined,
      }), "commit");
      const res = await api("PATCH", `/git/refs/heads/${branch}`, { sha: created.sha, force: false });
      if (res.ok) return created.sha;
      // 422: master moved since we read it. Rebuild on the new tip once.
      if (res.status !== 422 || attempt === 2) throw new GitHubError(`GitHub ref update failed (${res.status})`, res.status);
    }
  }

  return { exists, commit };
}
