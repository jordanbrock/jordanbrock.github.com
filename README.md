# jordanbrock.com

Personal blog, built with [Bridgetown](https://www.bridgetownrb.com) and deployed to GitHub Pages by GitHub Actions on every push to `master`.

## Requirements

- Ruby 4.0.5 (`.ruby-version`, installed with [mise](https://mise.jdx.dev))
- libvips >= 8.15 for the photo pipeline (`brew install vips`)

## Commands

```sh
bundle install
bin/bridgetown start       # dev server at http://localhost:4000
bin/bridgetown test        # test suite
bin/bridgetown deploy      # production build into ./output
bin/bridgetown check:urls  # fail if any URL in test/fixtures/legacy_urls.txt is missing from ./output
bin/bridgetown photos:strip  # strip GPS (and other metadata) from originals in src/photos
```

## Writing posts

Posts live in `src/_posts/` and get `/:year/:month/:day/:slug/` URLs. Posts imported from the old site keep their `.html` permalink in front matter so old URLs keep working.

The front matter decides the type (or set `type:` explicitly):

- **Article**: `title`, optional `excerpt` (otherwise the first paragraph is the summary).
- **Note**: no front matter needed.
- **Link**: `link`, optional `title` (otherwise the link's domain).
- **Photo**: `image`, a path under `src/photos/` (e.g. `2026/beach.jpg`), plus `alt`. The body is the caption.

Photos are resized into WebP and JPEG sizes at build time; originals in `src/photos/` are never published. A photo with GPS data fails the build: run `bin/bridgetown photos:strip` first.
