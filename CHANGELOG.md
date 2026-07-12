# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Bun version detection and display in the prompt.
- Explicit dirty/clean Git markers: dirty branches show a red `*`; clean
  branches show no marker.
- Optional async version detection via Oh My Zsh
  `_omz_register_handler`, with a dim `[…]` placeholder until results
  arrive and a sync `precmd` fallback when that API is absent.
- `CLEANSH_DISABLE_VERSION` to skip detection/display per tool
  (`ruby`, `node`/`nodejs`, `python`, `php`, `bun`).
- Documentation of version-manager precedence, caching, async behavior
  and disable list in the README.

### Changed

- Version detection now consults only the first available manager, in this
  order: `mise`, then `asdf`, then `nvm`. Results are never combined.
- `mise current` / `asdf current` run once and are parsed with native Zsh
  (no external `awk`).
- `preexec` cache invalidation targets `mise`, `asdf` and `nvm` after
  peeling wrappers (`command`, `noglob`, `exec`, `builtin`, `sudo`, `env`,
  `nice`, `nocorrect`, `time`), POSIX `--`, env assignments, and
  context-aware flags (e.g. `sudo -u user`, `env -i`, `nice -n 10`);
  path-qualified binaries match via basename.
- Nerd Font icons replace emoji for runtime versions.
- Tool display metadata (icons, colors, labels) centralized in a registry;
  runtime versions stored in an associative array keyed by tool name.
- Working directory in the prompt uses native `%~` (Oh My Zsh
  `prompt_subst`-safe).
- README updated for Bun, Nerd Font setup and current detection rules.

### Removed

- Fallbacks to `rvm`, `rbenv`, `ruby -v` and `bun --version`.
- Filling missing versions from a secondary manager when the primary one
  returns nothing.

### Fixed

- Nerd Font icons render correctly in Zsh via `$'\uXXXX'` icon variables.
- Async same-directory refresh no longer sticks stale versions when an
  in-flight worker finishes after `mise` / `asdf` / `nvm` (generation
  token in the payload).
- Async payload emit uses `print -rn` so Oh My Zsh’s `read -d ''` does
  not break decoding with a trailing newline.
- Version strings from managers are allowlisted (and capped) so project
  files cannot inject PROMPT escapes or control characters.
- Git prompting uses `git_prompt_info` again so OMZ git async and `%`
  escaping apply; avoids sync `git` on every version-worker repaint.
- `preexec` invalidates after path-qualified manager binaries (e.g.
  `/opt/homebrew/bin/mise`) and after `command -- mise`.
- `CLEANSH_DISABLE_VERSION` ignores unknown tool names (allowlist only).
- `mise` / `asdf` detected as shell functions as well as binaries.
- Async stable prompts skip re-decoding OMZ output when the parent cache
  is already valid; manager stdout parse is capped and payload size is
  bounded before decode.
- Indexing under `setopt ksharrays` no longer breaks async payload decode,
  `preexec` invalidation, or async `precmd` ordering (`emulate -L zsh` +
  `noksharrays` on those hot paths).
- Custom escaped-cwd machinery that put `${_cleanzsh_pwd}` in `PROMPT` is
  gone; under OMZ `prompt_subst` that could expand command substitutions
  from the path variable.

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

[unreleased]: https://github.com/diegoos/cleanzsh/compare/v0.5...HEAD
[0.5]: https://github.com/diegoos/cleanzsh/compare/v0.4...v0.5
[0.4]: https://github.com/diegoos/cleanzsh/compare/0.3...v0.4
[0.3]: https://github.com/diegoos/cleanzsh/releases/tag/0.3
