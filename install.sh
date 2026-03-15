#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills/autoresearch"
SKILL_NAME="autoresearch"
FULL_AUTO=0

usage() {
  cat <<'EOF'
Usage:
  ./install.sh           Auto-detect installed CLIs and install for each
  ./install.sh --claude  Install to ~/.claude/skills/autoresearch
  ./install.sh --opencode
  ./install.sh --codex
  ./install.sh --all
  ./install.sh --project Install into ./.agents/skills/autoresearch

Options:
  --full-auto  Allow ALL bash commands (for sandboxed/trusted environments)
EOF
}

ensure_source() {
  if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Missing source skill directory: $SOURCE_DIR" >&2
    exit 1
  fi
}

install_to_target() {
  local target="$1"

  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  cp -R "$SOURCE_DIR" "$target"
  echo "Installed $SKILL_NAME to $target"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# JSON merge helper — safely add allowedTools to an existing settings.json
# Uses jq if available, falls back to python3
# ---------------------------------------------------------------------------
merge_claude_permissions() {
  local file="$1"
  shift
  local rules=("$@")

  # Build a JSON array from the rules (values are safe ASCII, no escaping needed)
  local json_array
  json_array="["
  local first=1
  for rule in "${rules[@]}"; do
    if [[ "$first" -eq 1 ]]; then
      json_array="$json_array\"$rule\""
      first=0
    else
      json_array="$json_array,\"$rule\""
    fi
  done
  json_array="$json_array]"

  if [[ ! -f "$file" ]]; then
    mkdir -p "$(dirname "$file")"
    printf '{"permissions":{"allow":%s}}\n' "$json_array" > "$file"
    return
  fi

  # Merge into existing file, deduplicating allowedTools
  if has_cmd jq; then
    local tmp
    tmp="$(mktemp)"
    if jq --argjson new "$json_array" '
      .permissions //= {} |
      .permissions.allow = ((.permissions.allow // []) + $new | unique)
    ' "$file" > "$tmp"; then
      mv "$tmp" "$file"
    else
      rm -f "$tmp"
      return 1
    fi
  elif has_cmd python3; then
    python3 -c "
import json, sys
new_rules = json.loads(sys.argv[1])
with open(sys.argv[2]) as f:
    data = json.load(f)
perms = data.setdefault('permissions', {})
existing = perms.get('allow', [])
merged = sorted(set(existing + new_rules))
perms['allow'] = merged
with open(sys.argv[2], 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$json_array" "$file"
  else
    echo "Warning: neither jq nor python3 found; skipping permission merge for $file" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Permission configuration per platform
# ---------------------------------------------------------------------------
CLAUDE_CORE_RULES=(
  "Bash(git add *)"
  "Bash(git checkout *)"
  "Bash(git commit *)"
  "Bash(git diff *)"
  "Bash(git log *)"
  "Bash(git revert *)"
  "Bash(git show *)"
  "Bash(git stash *)"
  "Bash(git status *)"
  "Edit"
  "Write"
)

CLAUDE_FULL_AUTO_RULES=(
  "Bash"
  "Edit"
  "Write"
)

configure_claude_permissions() {
  local settings_file="$HOME/.claude/settings.json"
  if [[ "$FULL_AUTO" -eq 1 ]]; then
    merge_claude_permissions "$settings_file" "${CLAUDE_FULL_AUTO_RULES[@]}"
  else
    merge_claude_permissions "$settings_file" "${CLAUDE_CORE_RULES[@]}"
  fi
  echo "Configured permissions in $settings_file"
}

configure_project_permissions() {
  local settings_file="$PWD/.claude/settings.json"
  if [[ "$FULL_AUTO" -eq 1 ]]; then
    merge_claude_permissions "$settings_file" "${CLAUDE_FULL_AUTO_RULES[@]}"
  else
    merge_claude_permissions "$settings_file" "${CLAUDE_CORE_RULES[@]}"
  fi
  echo "Configured project permissions in $settings_file"
}

configure_codex_permissions() {
  local config_file="$HOME/.codex/config.toml"
  mkdir -p "$(dirname "$config_file")"
  if [[ -f "$config_file" ]] && grep -q 'approval_policy' "$config_file"; then
    sed 's/^approval_policy *= *"[^"]*"/approval_policy = "on-request"/' "$config_file" > "${config_file}.tmp" \
      && mv "${config_file}.tmp" "$config_file"
  else
    printf 'approval_policy = "on-request"\n' >> "$config_file"
  fi
  echo "Configured permissions in $config_file"
}

# ---------------------------------------------------------------------------
# Install functions
# ---------------------------------------------------------------------------
install_project() {
  install_to_target "$PWD/.agents/skills/$SKILL_NAME"
  configure_project_permissions
}

install_claude() {
  install_to_target "$HOME/.claude/skills/$SKILL_NAME"
  configure_claude_permissions
}

install_opencode() {
  install_to_target "$HOME/.config/opencode/skills/$SKILL_NAME"
}

install_codex() {
  install_to_target "$HOME/.codex/skills/$SKILL_NAME"
  configure_codex_permissions
}

auto_install() {
  local installed=0

  if has_cmd claude; then
    install_claude
    installed=1
  fi

  if has_cmd opencode; then
    install_opencode
    installed=1
  fi

  if has_cmd codex; then
    install_codex
    installed=1
  fi

  if [[ "$installed" -eq 0 ]]; then
    echo "No supported CLI detected. Use --claude, --opencode, --codex, --all, or --project." >&2
    exit 1
  fi
}

main() {
  ensure_source

  # Parse --full-auto from any position
  local args=()
  for arg in "$@"; do
    if [[ "$arg" == "--full-auto" ]]; then
      FULL_AUTO=1
    else
      args+=("$arg")
    fi
  done

  if [[ ${#args[@]} -eq 0 ]]; then
    auto_install
    exit 0
  fi

  case "${args[0]}" in
    --claude)
      install_claude
      ;;
    --opencode)
      install_opencode
      ;;
    --codex)
      install_codex
      ;;
    --all)
      install_claude
      install_opencode
      install_codex
      ;;
    --project)
      install_project
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
