// Snapshots of what the Worker writes for each kind of post. The site's
// test/test_worker_posts.rb reads these files, so a change to the Worker's
// output that the site can't read fails one side or the other.
import { expect, it } from "vitest";
import { buildPost } from "../src/post.js";

const now = new Date("2026-11-11T06:03:09Z");
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
const input = (o) => ({ kind: "note", content: "", url: "", title: "", tags: [], photos: [], ...o });

const cases = {
  note: input({ content: 'A "quoted" note: with a colon.\n\nAnd a second paragraph.', tags: ["birds"] }),
  link: input({ kind: "link", url: "https://example.com/a?b=1", title: "An example", content: "Worth a read." }),
  photo: input({ kind: "photos", photos: [{ bytes: jpeg, alt: "A heron in the shallows", caption: "Heron." }] }),
  album: input({
    kind: "photos", title: "Lake walk", content: "A morning at the lake.",
    photos: [{ bytes: jpeg, alt: "A heron", caption: "Heron" }, { bytes: jpeg, alt: "An egret", caption: "" }],
  }),
  // Strings YAML would turn into other types, a "#", and a body line of "---".
  awkward: input({
    kind: "photos", title: 'No: really, "yes" # not a comment',
    content: "Caf\u00e9 \u00fcber \ud83d\udc26\n\n---\n\nAfter the rule.",
    tags: ["null", "on"],
    photos: [{ bytes: jpeg, alt: "yes", caption: "2026-01-01" }, { bytes: jpeg, alt: "no", caption: "" }],
  }),
};

for (const [name, data] of Object.entries(cases)) {
  it(`writes the ${name} fixture`, async () => {
    await expect(buildPost(data, now).markdown).toMatchFileSnapshot(`./fixtures/${name}.md`);
  });
}
