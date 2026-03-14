# Contributing to Autoresearch

Thanks for your interest in contributing!

## Reporting Issues

Open a GitHub issue using the provided templates. Include your platform (macOS/Linux), shell, and the output of `./tests/test.sh`.

## Submitting Pull Requests

1. Fork the repo and create a feature branch from `main`.
2. Make your changes.
3. Run `./tests/test.sh` and confirm all tests pass.
4. If you changed `install.sh` or skill files, do a manual smoke test on at least one platform (see `tests/manual-smoke.md`).
5. Open a PR using the pull request template.

## Shell Style

- Use `bash` with `set -euo pipefail`.
- Quote all variable expansions.
- Prefer `printf` over `echo`.
- Keep functions short and focused.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).
