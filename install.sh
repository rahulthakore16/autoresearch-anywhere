#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills/autoresearch"
SKILL_NAME="autoresearch"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh           Auto-detect installed CLIs and install for each
  ./install.sh --claude  Install to ~/.claude/skills/autoresearch
  ./install.sh --opencode
  ./install.sh --codex
  ./install.sh --all
  ./install.sh --project Install into ./.agents/skills/autoresearch
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

install_project() {
  install_to_target "$PWD/.agents/skills/$SKILL_NAME"
}

install_claude() {
  install_to_target "$HOME/.claude/skills/$SKILL_NAME"
}

install_opencode() {
  install_to_target "$HOME/.config/opencode/skills/$SKILL_NAME"
}

install_codex() {
  install_to_target "$HOME/.codex/skills/$SKILL_NAME"
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

  if [[ $# -eq 0 ]]; then
    auto_install
    exit 0
  fi

  case "$1" in
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
