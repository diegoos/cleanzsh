# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-07-11

### Added

- Bun in the prompt; hide tools with `CLEANSH_DISABLE_VERSION`.
- Optional async version refresh via Oh My Zsh (`[…]` until ready; sync
  fallback when the API is missing).
- Dirty Git branches show a red `*`; clean branches show no marker.
- Changelog and a clearer README.

### Changed

- Use only the first manager found: `mise` → `asdf` → `nvm` (never merge
  results; one native parse of `mise`/`asdf current`).
- Nerd Font icons instead of emoji; tool display driven by a single
  registry.
- Cache invalidation after `mise`/`asdf`/`nvm`, including wrappers,
  flags, `command -- …`, and path-qualified binaries.
- CWD uses native `%~` (safe under Oh My Zsh `prompt_subst`).

### Removed

- Fallbacks to `rvm`, `rbenv`, `ruby -v`, `bun --version`, and filling
  gaps from a secondary manager.

### Fixed

- Nerd Font icons render correctly; manager versions are allowlisted
  before reaching the prompt.
- Async no longer sticks stale versions (generation token); payload and
  cache decoding are more robust; `ksharrays` no longer breaks decode /
  `preexec` / precmd order.
- `mise`/`asdf` work as functions or binaries; Git goes through
  `git_prompt_info` again (OMZ async + `%` escaping).

## [0.5] - 2026-03-22

### Added

- `preexec` hook to refresh cached versions after version-manager commands
  even when the directory does not change.
- Emoji icons next to detected runtime versions.

## [0.4] - 2026-03-12

### Added

- `mise` support for detecting Ruby, Node, Python and PHP versions.
- Per-directory cache of tool versions (`chpwd` / `precmd`) to avoid
  repeated subprocess calls on every prompt.
- Screenshot and README updates for the theme.

### Changed

- Theme file renamed from `dcleansh.zsh-theme` to `cleanzsh.zsh-theme`.
- Prefer `mise`, then fill gaps with `asdf` / `nvm`, with `rvm` / `rbenv`
  still able to override Ruby.
- Parse `mise current` and `asdf current` in a single call per manager
  (via `awk`) instead of one subprocess per tool.
- Prompt build refactored for clearer version assembly.

## [0.3] - 2021-04-22

### Added

- MIT license file.
- Prompt improvements for Ruby, Node and Python version display via
  `asdf` / `rvm` / `rbenv`.

[unreleased]: https://github.com/diegoos/cleanzsh/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/diegoos/cleanzsh/compare/v0.5...v0.6.0
[0.5]: https://github.com/diegoos/cleanzsh/compare/v0.4...v0.5
[0.4]: https://github.com/diegoos/cleanzsh/compare/0.3...v0.4
[0.3]: https://github.com/diegoos/cleanzsh/releases/tag/0.3
