# jordanbrock.com

Personal blog, built with [Bridgetown](https://www.bridgetownrb.com) and deployed to GitHub Pages by GitHub Actions on every push to `master`.

```sh
bundle install
bin/bridgetown start   # dev server at http://localhost:4000
bin/bridgetown deploy  # production build into ./output
```

Posts live in `src/_posts/`. Each post sets an explicit `permalink` so old URLs keep working.
