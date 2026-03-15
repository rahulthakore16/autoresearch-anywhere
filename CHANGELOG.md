# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-03-14

### Added
- Automatic permission configuration during install — no extra flags needed
- `--full-auto` flag for sandboxed/trusted environments (allows all bash commands)
- Claude Code: git command rules added to `~/.claude/settings.json` (or `.claude/settings.json` for `--project`)
- Codex CLI: `approval_policy = "on-request"` set in `~/.codex/config.toml`
- JSON merge helper with `jq` support and `python3` fallback for safe settings merging
- Permission tests: creation, merge with existing settings, idempotency, full-auto, project-level
- Permissions & Autonomy section in SKILL.md (agent-facing docs)
- Permissions section in README.md (user-facing docs)

## [2.0.0] - 2026-03-14

Initial open-source release.

### Added
- Cross-platform skill supporting Claude Code, OpenCode, and Codex CLI
- `install.sh` with auto-detect, explicit platform flags, and `--project` mode
- Automated test suite (`tests/test.sh`)
- Manual smoke test guide (`tests/manual-smoke.md`)
- CI workflow for Ubuntu and macOS
- GitHub issue and PR templates
- `CONTRIBUTING.md`
