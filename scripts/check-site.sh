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

# --- Task 1 ---
selftest
assert_file "$PLAIN/index.html"
assert_contains "$PLAIN/index.html" 'href="https://comanadrianioan\.github\.io/personal-site/css/'
assert_cmd "links keep sub-path" bash -c '! grep -rhoE "(href|src)=\"/[^\"]*" "$PLAIN" --include=*.html | grep -v "=\"/personal-site/"'
check_banned
assert_cmd "drafts are git-ignored" git check-ignore -q content/writing/drafts/example.md
assert_cmd "docs/ is git-ignored" git check-ignore -q docs/superpowers/specs/x.md

# --- Task 2 ---
assert_contains "$PLAIN/index.html" 'personal-site/terminal\.css'
assert_contains "$PLAIN/index.html" 'personal-site/style\.css'
assert_contains "$PLAIN/index.html" "© $(date +%Y) Adrian-Ioan Coman"
assert_not_contains "$PLAIN/index.html" 'panr'
for img in favicon.png apple-touch-icon.png og-image.png; do
  assert_cmd "own $img (not the theme's)" cmp -s "static/$img" "$PLAIN/$img"
done
if command -v sips >/dev/null; then
  assert_cmd "og-image is 1200x627" bash -c 'sips -g pixelWidth -g pixelHeight static/og-image.png | tr -d " " | grep -c -E "pixelWidth:1200|pixelHeight:627" | grep -qx 2'
else
  skip "og-image size (no sips on this machine)"
fi

# ---------------------------------------------------------------- result
if [ "$FAILS" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$FAILS CHECK(S) FAILED"; exit 1; fi
