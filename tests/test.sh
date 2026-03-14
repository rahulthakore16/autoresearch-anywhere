#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"
SKILL_DIR="$ROOT_DIR/skills/autoresearch"

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file: $path"
}

assert_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory: $path"
}

test_repo_sanity() {
  assert_dir "$SKILL_DIR"
  assert_file "$SKILL_DIR/SKILL.md"
  assert_file "$SKILL_DIR/references/autonomous-loop-protocol.md"
  assert_file "$SKILL_DIR/references/core-principles.md"
  assert_file "$SKILL_DIR/references/results-logging.md"

  grep -q '^name: autoresearch$' "$SKILL_DIR/SKILL.md" || fail "missing skill name frontmatter"
  grep -q '^description:' "$SKILL_DIR/SKILL.md" || fail "missing skill description frontmatter"
  ! grep -q 'Claude Autoresearch' "$SKILL_DIR/SKILL.md" || fail "stale Claude-specific branding remains"
  ! grep -q '/ug:' "$SKILL_DIR/SKILL.md" || fail "stale Claude namespace trigger remains"

  bash -n "$INSTALL_SCRIPT" || fail "install.sh failed syntax check"

  pass "repo sanity"
}

test_project_install() {
  local tmpdir
  tmpdir="$(mktemp -d)"

  (
    cd "$tmpdir"
    "$INSTALL_SCRIPT" --project >/dev/null
    assert_dir "$tmpdir/.agents/skills/autoresearch"
    assert_file "$tmpdir/.agents/skills/autoresearch/SKILL.md"
    assert_dir "$tmpdir/.agents/skills/autoresearch/references"
  )

  pass "project install"
}

test_explicit_platform_installs() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude >/dev/null
  HOME="$tmp_home" "$INSTALL_SCRIPT" --opencode >/dev/null
  HOME="$tmp_home" "$INSTALL_SCRIPT" --codex >/dev/null

  assert_file "$tmp_home/.claude/skills/autoresearch/SKILL.md"
  assert_file "$tmp_home/.config/opencode/skills/autoresearch/SKILL.md"
  assert_file "$tmp_home/.codex/skills/autoresearch/SKILL.md"

  pass "explicit platform installs"
}

test_auto_install_detects_only_stubbed_clis() {
  local tmp_home stub_bin
  tmp_home="$(mktemp -d)"
  stub_bin="$(mktemp -d)"

  ln -s /usr/bin/true "$stub_bin/claude"
  ln -s /usr/bin/true "$stub_bin/codex"

  env HOME="$tmp_home" PATH="$stub_bin:/usr/bin:/bin" "$INSTALL_SCRIPT" >/dev/null

  assert_file "$tmp_home/.claude/skills/autoresearch/SKILL.md"
  assert_file "$tmp_home/.codex/skills/autoresearch/SKILL.md"
  [[ ! -e "$tmp_home/.config/opencode/skills/autoresearch" ]] || fail "unexpected opencode install"

  pass "auto install detects only stubbed CLIs"
}

test_auto_install_fails_without_supported_clis() {
  local tmp_home output exit_code
  tmp_home="$(mktemp -d)"
  output="$(mktemp)"
  exit_code=0

  set +e
  env HOME="$tmp_home" PATH="/usr/bin:/bin" "$INSTALL_SCRIPT" >"$output" 2>&1
  exit_code=$?
  set -e

  [[ "$exit_code" -ne 0 ]] || fail "auto install should fail when no supported CLIs are present"
  grep -q 'No supported CLI detected' "$output" || fail "missing helpful no-CLI error"

  pass "auto install failure path"
}

test_smoke_workspace_bootstrap() {
  local tmpdir
  tmpdir="$(mktemp -d)"

  (
    cd "$tmpdir"
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"
    printf 'alpha\n' > score.txt
    printf '# metric_direction: higher_is_better\niteration\tcommit\tmetric\tdelta\tstatus\tdescription\n0\t-\t6\t0.0\tbaseline\tinitial state\n' > autoresearch-results.tsv
    "$INSTALL_SCRIPT" --project >/dev/null
    test -d .git || fail "smoke repo missing git metadata"
    test -f .agents/skills/autoresearch/SKILL.md || fail "smoke repo missing installed skill"
    test -f autoresearch-results.tsv || fail "smoke repo missing local results log"
    test "$(wc -c < score.txt | tr -d ' ')" = "6" || fail "smoke verification command mismatch"
  )

  pass "smoke workspace bootstrap"
}

main() {
  test_repo_sanity
  test_project_install
  test_explicit_platform_installs
  test_auto_install_detects_only_stubbed_clis
  test_auto_install_fails_without_supported_clis
  test_smoke_workspace_bootstrap
  printf 'All tests passed.\n'
}

main "$@"
