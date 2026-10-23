# personal-site

Adrian-Ioan Coman's personal site — Hugo + the [Terminal](https://github.com/panr/hugo-theme-terminal) theme (Hugo Module), published at <https://comanadrianioan.github.io/personal-site/>.

- **Run locally:** `hugo server --baseURL http://localhost:1313/personal-site/`
- **Run the checks:** `scripts/check-site.sh` (CI runs the same script; a failing check blocks the deploy)
- **New draft:** `hugo new content writing/drafts/<slug>.md`, preview with `hugo server -D --baseURL http://localhost:1313/personal-site/`
- **Drafts are git-ignored on purpose:** this repo is public, so `draft: true` alone would not keep a draft private.
- **Publish a draft:** move it to `content/writing/`, delete the `draft: true` line, commit, push to `main`.
- **Deploys:** every push to `main` builds and publishes via `.github/workflows/deploy.yml`.
- **Add LinkedIn later:** set `linkedin` under `[params.links]` in `hugo.toml`, add the link to `content/_index.md` and `content/about.md`, and remove the "no LinkedIn link" check from `scripts/check-site.sh`.
- **Add a photo later:** put it in `static/images/` and add a Markdown image to `content/about.md`.
- **Update the theme:** `hugo mod get -u github.com/panr/hugo-theme-terminal/v4`, then run the checks and look at the site before committing `go.mod`/`go.sum` — theme updates are unreviewed third-party code. `layouts/_default/single.html` and `layouts/partials/footer.html` are copies of theme files; compare them with the new theme version.
- **Icons/preview image:** sources are in `assets-src/` (not Hugo's `assets/`); re-render with `sips` into `static/` (see the commit that added them).
