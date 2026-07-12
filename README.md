# CleanSH ZSH Theme

CleanSH is a lightweight, performance-minded Zsh prompt theme that shows the
current user, working directory, Git branch and detected runtime versions
(Ruby, Node, Python, PHP, Bun) with compact icons and minimal overhead.

## Features

- Detects runtime versions from a single version manager, in this order:
  `mise`, then `asdf`, then `nvm`. Only the first available manager is used;
  results are never combined and there is no fallback when that manager
  returns no version.
- Recognizes `ruby`, `node`/`nodejs`, `python`, `php` and `bun`.
- Runs `mise current` or `asdf current` once and parses the output with
  native Zsh (no external `awk`).
- For `nvm`, uses `nvm current`, strips the `v` prefix, and ignores `none`
  and `system`.
- Version strings are allowlisted (`[0-9][0-9A-Za-z._+-]*`, max 64 chars,
  no control characters) so untrusted project files cannot inject PROMPT
  escapes.
- Working directory uses native `%~` (safe under Oh My Zsh `prompt_subst`;
  no custom path-escape machinery in the theme).
- Optional async path when Oh My Zsh exposes `_omz_register_handler`: the
  first prompt, directory changes, and post-`mise`/`asdf`/`nvm` refreshes
  show a dim `[…]` placeholder until the worker returns; stale results
  from another directory or an invalidated generation are discarded.
  Without that API, a sync `precmd` fallback expands the cached fragment
  directly (no placeholder, no `$()` for versions).
- Per-directory caching (keyed also by `CLEANSH_DISABLE_VERSION`) to avoid
  repeated tool calls; cache is also invalidated after `mise`, `asdf` or
  `nvm` commands via `preexec`. Path-qualified binaries match via basename.
  Wrappers peeled: `command`, `noglob`, `exec`, `builtin`, `sudo`, `env`,
  `nice`, `nocorrect`, `time`, POSIX `--`, and env assignments. Context-aware
  flags are peeled too (e.g. `sudo -u user`, `env -i`, `nice -n 10`,
  `command -- mise`). Combined short flags like `sudo -nu` and command
  chains (`npm && mise`) are not covered.
- Optional per-tool disable via `CLEANSH_DISABLE_VERSION` (unknown names
  are ignored).
- Git branch via Oh My Zsh `git_prompt_info` (supports OMZ git async when
  enabled by the host): dirty branches show a red `*`; clean branches show
  no marker.
- Small Nerd Font icons next to each version.
- Requires a Nerd Font (such as Fira Code Nerd Font) for proper icon
  rendering.

## Screenshot

![Print screen cleansh theme](print.png)

## Install

### Prerequisites

Install the **Fira Code Nerd Font** to display the version icons properly:

```sh
brew install --cask font-fira-code-nerd-font
```

Then set it as your terminal's font in your terminal settings.

### Installation

Copy `cleanzsh.zsh-theme` into your Zsh themes directory (for example
`~/.oh-my-zsh/custom/themes/`).

Then set the theme in your `~/.zshrc`:

```sh
ZSH_THEME="cleanzsh"
```

Reload the shell or source your `~/.zshrc`.

## Configuration

### Disable runtime versions

Set `CLEANSH_DISABLE_VERSION` to a comma-separated list of tools to skip
detection and display for. Accepted values: `ruby`, `node` (or `nodejs`),
`python`, `php`, `bun`. Matching is case-insensitive; spaces around names
are ignored. Unknown names are ignored.

```sh
# Hide PHP and Ruby versions in the prompt
export CLEANSH_DISABLE_VERSION="php,ruby"
```

```sh
# Hide everything except Node
export CLEANSH_DISABLE_VERSION="ruby,python,php,bun"
```

Add the export to your `~/.zshrc` (before or after the theme is loaded).
The disable list is part of the cache key: changes take effect on the next
prompt (async mode may briefly show `[…]` first).

## Notes

- Product name is **CleanSH**; theme id / file is `cleanzsh`; env vars use
  the `CLEANSH_` prefix.
- The theme does not fall back to `rvm`, `rbenv`, `ruby -v` or
  `bun --version`; only `mise`, `asdf` and `nvm` are consulted, in that
  order.
- Async support uses Oh My Zsh’s experimental `_omz_register_handler` API
  when present. That API may change; the sync fallback keeps the theme
  usable without it.
- Git uses `$(git_prompt_info)` so OMZ can run git async when configured
  (`zstyle ':omz:alpha:lib:git' async-prompt …` before sourcing Oh My Zsh).
  OMZ already escapes `%` in branch names; this theme does not reimplement
  git prompting.
- It is non-invasive: it does not override existing tool functions and uses
  `preexec`/`precmd`/`chpwd` hooks to keep the prompt up-to-date.
- Version managers exposed as shell functions (`mise`, `asdf`, `nvm`) or
  as binaries on `PATH` are detected; the function is preferred when both
  exist (typical after `activate`).

## License

See the repository [LICENSE](LICENSE) file.
