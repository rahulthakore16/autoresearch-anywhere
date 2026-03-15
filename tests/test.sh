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

# Helper: check that a JSON file contains a given string
assert_json_contains() {
  local file="$1" pattern="$2"
  grep -q "$pattern" "$file" || fail "expected $file to contain: $pattern"
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

# ---------------------------------------------------------------------------
# Permission tests
# ---------------------------------------------------------------------------

test_claude_permissions_created() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude >/dev/null

  local settings="$tmp_home/.claude/settings.json"
  assert_file "$settings"
  assert_json_contains "$settings" '"Bash(git commit \*)"'
  assert_json_contains "$settings" '"Edit"'
  assert_json_contains "$settings" '"Write"'

  pass "claude permissions created"
}

test_claude_permissions_merge_existing() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  # Pre-populate settings with existing data
  mkdir -p "$tmp_home/.claude"
  printf '{"theme":"dark","permissions":{"allow":["Bash(npm test *)"]}}\n' > "$tmp_home/.claude/settings.json"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude >/dev/null

  local settings="$tmp_home/.claude/settings.json"
  # Existing rules preserved
  assert_json_contains "$settings" '"Bash(npm test \*)"'
  # New rules added
  assert_json_contains "$settings" '"Bash(git commit \*)"'
  # Existing top-level keys preserved
  assert_json_contains "$settings" '"theme"'

  pass "claude permissions merge existing"
}

test_claude_permissions_idempotent() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude >/dev/null
  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude >/dev/null

  local settings="$tmp_home/.claude/settings.json"
  # Count occurrences of "Edit" — should appear exactly once
  local count
  count="$(grep -o '"Edit"' "$settings" | wc -l | tr -d ' ')"
  [[ "$count" -eq 1 ]] || fail "permissions not idempotent: Edit appears $count times"

  pass "claude permissions idempotent"
}

test_full_auto_permissions() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --claude --full-auto >/dev/null

  local settings="$tmp_home/.claude/settings.json"
  assert_file "$settings"
  # Full-auto should have bare "Bash" (not "Bash(git ...)")
  assert_json_contains "$settings" '"Bash"'
  # Should NOT contain git-specific rules
  if grep -q '"Bash(git commit \*)"' "$settings"; then
    fail "full-auto should not contain git-specific rules"
  fi

  pass "full-auto permissions"
}

test_project_permissions() {
  local tmpdir
  tmpdir="$(mktemp -d)"

  (
    cd "$tmpdir"
    "$INSTALL_SCRIPT" --project >/dev/null
    local settings="$tmpdir/.claude/settings.json"
    assert_file "$settings"
    assert_json_contains "$settings" '"Bash(git commit \*)"'
    assert_json_contains "$settings" '"Edit"'
  )

  pass "project permissions"
}

test_permissions_always_created() {
  local tmp_home stub_bin
  tmp_home="$(mktemp -d)"
  stub_bin="$(mktemp -d)"

  ln -s /usr/bin/true "$stub_bin/claude"

  env HOME="$tmp_home" PATH="$stub_bin:/usr/bin:/bin" "$INSTALL_SCRIPT" >/dev/null

  local settings="$tmp_home/.claude/settings.json"
  assert_file "$settings"
  assert_json_contains "$settings" '"Bash(git commit \*)"'

  pass "permissions always created"
}

test_codex_permissions_created() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --codex >/dev/null

  local config="$tmp_home/.codex/config.toml"
  assert_file "$config"
  grep -q '^approval_policy = "on-request"' "$config" || fail "codex config missing approval_policy"

  pass "codex permissions created"
}

test_codex_permissions_update_existing() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  # Pre-populate with a different policy
  mkdir -p "$tmp_home/.codex"
  printf 'model = "o4-mini"\napproval_policy = "full-auto"\n' > "$tmp_home/.codex/config.toml"

  HOME="$tmp_home" "$INSTALL_SCRIPT" --codex >/dev/null

  local config="$tmp_home/.codex/config.toml"
  grep -q '^approval_policy = "on-request"' "$config" || fail "codex config not updated"
  # Existing keys preserved
  grep -q '^model = "o4-mini"' "$config" || fail "codex config lost existing keys"
  # Comment lines with approval_policy should not be modified
  if grep -q '# approval_policy' "$config"; then
    fail "sed should not match commented lines"
  fi

  pass "codex permissions update existing"
}

main() {
  test_repo_sanity
  test_project_install
  test_explicit_platform_installs
  test_auto_install_detects_only_stubbed_clis
  test_auto_install_fails_without_supported_clis
  test_smoke_workspace_bootstrap
  test_claude_permissions_created
  test_claude_permissions_merge_existing
  test_claude_permissions_idempotent
  test_full_auto_permissions
  test_project_permissions
  test_permissions_always_created
  test_codex_permissions_created
  test_codex_permissions_update_existing
  printf 'All tests passed.\n'
}

main "$@"
