# personal-site

Adrian-Ioan Coman's personal site — Hugo + the [Terminal](https://github.com/panr/hugo-theme-terminal) theme (Hugo Module), published at <https://comanadrianioan.github.io/personal-site/>.

- **Run locally:** `hugo server --baseURL http://localhost:1313/personal-site/`
- **Run the checks:** `scripts/check-site.sh` (CI runs the same script; a failing check blocks the deploy). The theme switch test, `tests/theme-switch.test.mjs`, needs Node and is skipped without it.
- **New draft:** `hugo new content writing/drafts/<slug>.md`, preview with `hugo server -D --baseURL http://localhost:1313/personal-site/`
- **Drafts are git-ignored on purpose:** this repo is public, so `draft: true` alone would not keep a draft private.
- **Publish a draft:** move it to `content/writing/`, delete the `draft: true` line, commit, push to `main`.
- **Deploys:** every push to `main` builds and publishes via `.github/workflows/deploy.yml`.
- **Add a photo later:** put it in `static/images/` and add a Markdown image to `content/about.md`.
- **Styles:** all site CSS is in `assets/site/style.css`; it's bundled after the theme's CSS into one file (see `layouts/partials/head.html`).
- **Update the theme:** `hugo mod get -u github.com/panr/hugo-theme-terminal/v4`, then run the checks and look at the site before committing `go.mod`/`go.sum` — theme updates are unreviewed third-party code. These files are modified copies of theme files; compare them with the new theme version: `layouts/partials/head.html`, `layouts/partials/footer.html`, `layouts/_default/single.html`, `layouts/404.html`. Fully custom (no theme counterpart to merge): `layouts/partials/header.html`, `layouts/_default/index.html`, `layouts/_default/about.html`, `layouts/writing/list.html`, `layouts/home.rss.xml`.
- **Edit the About page:** the intro is the body of `content/about.md`; experience, education and skills are lists in its front matter. A skill with a `dir` also shows in the home page's `ls ~/skills`; the home page's `ls ~/work` comes from the experience list.
- **Change the tagline:** `tagline` in `hugo.toml`. The first part is the role under the name on the home page; all parts joined with " · " are the site description.
- **Icons/preview image:** sources are in `assets-src/` (not Hugo's `assets/`); re-render with `sips` into `static/` (see the commit that added them).
