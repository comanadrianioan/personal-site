#!/usr/bin/env bash
# Builds the site twice (as-is, and with test fixture posts mounted from
# tests/fixtures/) and checks the generated output.
# Usage: scripts/check-site.sh   — exits 1 if any check fails. Runs locally and in CI.
set -uo pipefail
cd "$(dirname "$0")/.."

FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
skip() { echo "SKIP: $1"; }

# Every check refuses to run without both build outputs: an empty $PLAIN would
# make negated greps ("! grep ...") pass without looking at anything.
outputs_ok() {
  local d
  for d in "${PLAIN:-}" "${FIX:-}"; do
    [ -n "$d" ] && [ -f "$d/index.html" ] || return 1
  done
}
guard() { outputs_ok || { fail "harness: output dir missing ($1)"; return 1; }; }

assert_file() {
  guard "$1" || return 1
  if [ -f "$1" ]; then pass "file exists: $1"; else fail "file missing: $1"; fi
}
assert_contains() {
  guard "$1" || return 1
  if grep -qE -- "$2" "$1" 2>/dev/null; then pass "$1 contains /$2/"; else fail "$1 lacks /$2/"; fi
}
assert_not_contains() {
  guard "$1" || return 1
  if [ ! -f "$1" ]; then fail "file missing: $1"
  elif grep -qE -- "$2" "$1"; then fail "$1 contains /$2/"
  else pass "$1 has no /$2/"; fi
}
assert_cmd() {
  local desc=$1; shift
  guard "$desc" || return 1
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}
# Content-wide search over generated HTML/XML; -I skips binary files (fonts).
grep_site() { grep -rIliE --include='*.html' --include='*.xml' -- "$1" "$PLAIN" "$FIX"; }
export -f grep_site

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PLAIN="$TMP/plain"
FIX="$TMP/fix"
export PLAIN FIX

build() {
  local name=$1 dest=$2; shift 2
  local log="$TMP/$name.log"
  if hugo --gc -d "$dest" --logLevel warn "$@" >"$log" 2>&1 && ! grep -qE 'WARN|ERROR' "$log"; then
    pass "build: $name"
  else
    fail "build: $name"
    sed 's/^/    /' "$log"
  fi
}

build plain "$PLAIN"
build fixtures "$FIX" --config hugo.toml,tests/hugo.test.toml
build minified "$TMP/minified" --minify

check_banned() { assert_cmd "no banned content (JDD, Kraków, talks, mailto)" bash -c '! grep_site "JDD|Krak(o|ó)w|/talks/|mailto:"'; }

# Proves the harness can fail: each negative case must record a FAIL.
selftest() {
  local ok=1
  guard "harness self-test" || return 1
  echo '<p>JDD</p>' >"$PLAIN/__selftest.html"
  (FAILS=0; check_banned >/dev/null; [ "$FAILS" -gt 0 ]) || ok=0
  rm -f "$PLAIN/__selftest.html"
  (PLAIN=""; FAILS=0; assert_file "$FIX/index.html" >/dev/null; [ "$FAILS" -gt 0 ]) || ok=0
  if [ "$ok" = 1 ]; then pass "harness self-test: negative cases fail"; else fail "harness self-test: a negative case passed"; fi
}

# ---------------------------------------------------------------- checks
POST="$FIX/writing/java-and-genai/index.html"
css_has() { assert_cmd "styles: $1" grep -qE -- "$2" "$PLAIN"/css/*.css; }

# --- Build & hosting
selftest
assert_contains "$PLAIN/index.html" 'href="https://comanadrianioan\.github\.io/personal-site/css/'
# Root-relative AND absolute same-host links, in both builds (post pages exist only in $FIX).
assert_cmd "links keep sub-path" bash -c '! grep -rhoE "(href|src)=\"(https://comanadrianioan\.github\.io)?/[^\"]*" "$PLAIN" "$FIX" --include=*.html | grep -vE "=\"(https://comanadrianioan\.github\.io)?/personal-site/"'
check_banned
assert_cmd "drafts are git-ignored" git check-ignore -q content/writing/drafts/example.md
assert_cmd "docs/ is git-ignored" git check-ignore -q docs/superpowers/specs/x.md
assert_contains "$PLAIN/sitemap.xml" '/personal-site/about/'
# All CSS ships as one bundle, and the theme's unused Fira Code fonts are not referenced.
assert_cmd "exactly one stylesheet" bash -c '[ "$(grep -o "rel=\"stylesheet\"" "$PLAIN/index.html" | wc -l | tr -d " ")" = 1 ]'
assert_cmd "no Fira Code reference" bash -c '! grep -rq "FiraCode" "$PLAIN/css"'
assert_not_contains "$PLAIN/index.html" 'panr'
for img in favicon.png apple-touch-icon.png og-image.png; do
  assert_cmd "own $img (not the theme's)" cmp -s "static/$img" "$PLAIN/$img"
done
if command -v sips >/dev/null; then
  assert_cmd "og-image is 1200x627" bash -c 'sips -g pixelWidth -g pixelHeight static/og-image.png | tr -d " " | grep -c -E "pixelWidth:1200|pixelHeight:627" | grep -qx 2'
else
  skip "og-image size (no sips on this machine)"
fi

# --- Every page: skip link to #main, the footer with both profile links, none in the top bar.
# The <header>/<footer>/<article> checks cut that element out with awk, since its markup spans lines.
for page in "$PLAIN/index.html" "$PLAIN/about/index.html" "$PLAIN/writing/index.html" "$PLAIN/404.html" "$POST"; do
  name=${page#"$TMP"/}
  assert_contains "$page" 'class="skip-link" href="#main"'
  assert_contains "$page" 'id="main"'
  assert_cmd "footer © and profile links: $name" bash -c 'f=$(awk "/<footer[ >]/,/<\/footer>/" "$1"); grep -q "© $(date +%Y) Adrian-Ioan Coman" <<<"$f" && grep -q "href=\"https://www.linkedin.com/in/adrian-ioan-coman/\"" <<<"$f" && grep -q "href=\"https://github.com/comanadrianioan\"" <<<"$f"' _ "$page"
  assert_cmd "no profile links in top bar: $name" bash -c '! awk "/<header[ >]/,/<\/header>/" "$1" | grep -qiE "linkedin|github"' _ "$page"
done
# Own header: both menu items are plain links, no theme dropdown.
assert_contains "$PLAIN/index.html" 'class="site-nav"'
assert_contains "$PLAIN/index.html" 'href="/personal-site/about/"'
assert_contains "$PLAIN/index.html" 'href="/personal-site/writing/"'
assert_not_contains "$PLAIN/index.html" 'menu__dropdown|menu__trigger'
assert_contains "$PLAIN/index.html" 'name="twitter:card" content="summary_large_image"'
# Each page gets a description: home from the tagline, writing from its front matter,
# a post without one from its summary, 404 from the site fallback.
assert_contains "$PLAIN/index.html" '<meta name="description" content="Senior Engineer @ CrowdStrike · GenAI · Speaker · Runs on coffee"'
for page in "$PLAIN/writing/index.html" "$PLAIN/404.html" "$FIX/writing/older-post/index.html"; do
  assert_contains "$page" '<meta name="description" content="[^"]+'
done

# --- Home: name, role (first tagline part only), terminal from about.md
assert_contains "$PLAIN/index.html" 'class="tagline"><span>Senior Engineer @ CrowdStrike</span>'
assert_contains "$PLAIN/index.html" '\$ whoami'
assert_contains "$PLAIN/index.html" '<span>genai/</span>'
assert_not_contains "$PLAIN/index.html" 'software-design/'
assert_not_contains "$PLAIN/index.html" 'class="recent[ "]'
assert_contains "$FIX/index.html" 'class="recent[ "]'

# --- About: compressed per company, no years (only CrowdStrike is marked "Present"), earlier roles left out
for word in Playtika CrowdStrike POLITEHNICA Present 'Software Design'; do
  assert_contains "$PLAIN/about/index.html" "$word"
done
assert_cmd "no years on About" bash -c '! awk "/<article[ >]/,/<\/article>/" "$PLAIN/about/index.html" | grep -qE "(^|[^0-9])(19|20)[0-9]{2}([^0-9]|$)"'
assert_not_contains "$PLAIN/about/index.html" 'Tag4it|1&amp;1|IONOS'
assert_not_contains "$PLAIN/about/index.html" '>Elsewhere<'

# --- Writing: empty state without posts; with posts, escaped titles, newest first
assert_contains "$PLAIN/writing/index.html" 'class="empty">No posts yet'
assert_not_contains "$PLAIN/writing/index.html" 'class="[^"]*post-list'
for page in index.html writing/index.html; do
  assert_contains "$FIX/$page" 'Java &amp; GenAI: &lt;notes&gt;'
  assert_cmd "newest first: $page" bash -c 'grep -oE "java-and-genai|older-post" "$FIX/'"$page"'" | head -1 | grep -q java-and-genai'
done
assert_cmd "home RSS lists only writing posts" bash -c '[ "$(grep -c "<item>" "$FIX/index.xml")" = 2 ] && ! grep -q "/about/" "$FIX/index.xml"'
assert_contains "$FIX/index.xml" 'Java &amp;amp; GenAI|Java &amp; GenAI'
assert_cmd "archetype creates drafts" grep -q '^draft: true' archetypes/writing.md

# --- Posts
# The theme markdownifies titles, which silently drops "<...>" on the post page itself.
assert_contains "$POST" '/writing/java-and-genai/">Java &amp; GenAI: &lt;notes&gt;</a>'
assert_contains "$POST" 'Sep 1, 2026'
assert_contains "$POST" 'class="back-link" href="/personal-site/writing/"'
assert_contains "$POST" 'class="hanchor" aria-label="Link to this section"'
assert_contains "$POST" 'class="highlight"'
assert_not_contains "$FIX/writing/older-post/index.html" 'href="/personal-site/tags/'
# The theme's prev/next block shows a heading from params.readOtherPosts.
assert_not_contains "$FIX/writing/older-post/index.html" 'class="pagination__title-h"></span>'
assert_contains "$PLAIN/404.html" 'no such file or directory'

# --- Styles
# The theme's code.js adds a language label and a copy button; syntax colours come from the
# terminal palette so they stay readable on the always-dark code background.
css_has "code label"            '\.code-title\{'
css_has "copy button"           '\.copy-button\{'
css_has "code function colour"  '\.highlight\{[^}]*--first-tone:var\(--term-prompt\)'
css_has "code keyword colour"   '\.highlight\{[^}]*--second-tone:var\(--term-dir\)'
css_has "code text colour"      '\.highlight\{[^}]*--foreground:var\(--term-ink\)'
# The cursor blinks a few times, then stays solid (WCAG 2.2.2: under 5 seconds).
css_has "cursor stops blinking" 'animation:blink 1\.1s steps\(1\) ?4[;}]'
# Theme switch: every click flips what is shown (tests/theme-switch.test.mjs).
if command -v node >/dev/null; then
  assert_cmd "theme switch behaviour" node tests/theme-switch.test.mjs
else
  skip "theme switch behaviour (no node on this machine)"
fi

# --- Source hygiene: one palette, one source per value, no dead code
assert_cmd "colour tokens defined once" bash -c '[ "$(grep -c -- "--bg:" assets/site/style.css)" = 1 ]'
assert_cmd "no unused styles" bash -c '! grep -qE "\.section-head|\.nav-icon|!important" assets/site/style.css'
# The footer's script (the theme's code.js only): it must exist, and not contain the theme's menu.js.
assert_cmd "no theme menu script" bash -c 'js=$(grep -oE "src=\"/personal-site/[^\"]+\.js\"" "$PLAIN/index.html" | grep -v theme | head -1 | sed -E "s#src=\"/personal-site/##; s#\"##"); [ -n "$js" ] && [ -f "$PLAIN/$js" ] && ! grep -q "menu__trigger" "$PLAIN/$js"'
assert_cmd "no duplicate skills or subtitle in hugo.toml" bash -c '! grep -qE "^[[:space:]]*(skills|subtitle)[[:space:]]*=" hugo.toml'
assert_cmd "no dead theme config" bash -c '! grep -qE "showMenuItems|logoText" hugo.toml'

# --- Deploy workflow
WF=.github/workflows/deploy.yml
assert_file "$WF"
assert_not_contains "$WF" '^[[:space:]]*schedule:'
assert_cmd "every action pinned to a commit SHA" bash -c '[ -f '"$WF"' ] && ! grep -E "^[[:space:]]*-?[[:space:]]*uses:" '"$WF"' | grep -vqE "@[0-9a-f]{40}"'
assert_cmd "CI Hugo version == local Hugo version" bash -c 'v=$(hugo version | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+" | head -1); grep -q "HUGO_VERSION: ${v#v}" '"$WF"
assert_cmd "workflow-level permissions empty" grep -qE '^permissions: \{\}' "$WF"
assert_cmd "build job is read-only" bash -c 'b=$(awk "/^  build:/,/^  deploy:/" '"$WF"'); echo "$b" | grep -q "contents: read" && ! echo "$b" | grep -qE "pages: write|id-token: write"'
assert_cmd "deploy job can deploy" bash -c 'awk "/^  deploy:/,0" '"$WF"' | grep -q "id-token: write"'
assert_contains "$WF" 'scripts/check-site\.sh'
assert_cmd "no personal secrets in workflow" bash -c '[ -f '"$WF"' ] && ! grep -oE "secrets\.[A-Za-z_]+" '"$WF"' | grep -v "secrets.GITHUB_TOKEN"'
assert_file README.md

# ---------------------------------------------------------------- result
if [ "$FAILS" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$FAILS CHECK(S) FAILED"; exit 1; fi
