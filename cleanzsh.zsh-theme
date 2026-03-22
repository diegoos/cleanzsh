local user_host='%{$terminfo[bold]$fg[green]%}$(whoami)%{$reset_color%}'
local user_symbol='$'

local current_dir='%{$terminfo[bold]$fg[blue]%}%~%{$reset_color%}'

# Cache of tool versions — refreshed only when the current directory changes.
# Uses a single `asdf current` / `mise current` call instead of per-tool subprocess calls.
typeset -g _tool_versions=""
typeset -g _tool_versions_dir=""

_update_tool_versions() {
  if [[ "$PWD" == "$_tool_versions_dir" && -z "${_tool_pending_update:-}" ]]; then
    return
  fi
  _tool_versions_dir="$PWD"
  unset _tool_pending_update

  local ruby_ver="" node_ver="" python_ver="" php_ver="" versions=""

  # Single mise call covers all active tools at once.
  # Use one awk invocation to avoid multiple forks for parsing.
  if command -v mise &>/dev/null; then
    local _mise_out _mise_parsed
    _mise_out=$(mise current 2>/dev/null)
    _mise_parsed=$(awk '
      $1=="ruby"   && $2~/^[0-9]/{r=$2}
      $1=="node"   && $2~/^[0-9]/{n=$2}
      $1=="python" && $2~/^[0-9]/{p=$2}
      $1=="php"    && $2~/^[0-9]/{ph=$2}
      END{print r "|" n "|" p "|" ph}
    ' <<< "$_mise_out")
    local IFS='|'
    read -r ruby_ver node_ver python_ver php_ver <<< "$_mise_parsed"
  fi

  # Single asdf call fills any gaps left by mise (or replaces it when mise is absent).
  if command -v asdf &>/dev/null && [[ -z "$ruby_ver" || -z "$node_ver" || -z "$python_ver" || -z "$php_ver" ]]; then
    local _asdf_out _asdf_parsed
    _asdf_out=$(asdf current 2>/dev/null)
    _asdf_parsed=$(awk '
      $1=="ruby"   && $2~/^[0-9]/{r=$2}
      $1=="nodejs" && $2~/^[0-9]/{n=$2}
      $1=="python" && $2~/^[0-9]/{p=$2}
      $1=="php"    && $2~/^[0-9]/{ph=$2}
      END{print r "|" n "|" p "|" ph}
    ' <<< "$_asdf_out")
    local IFS='|'
    read -r _r _n _p _ph <<< "$_asdf_parsed"
    [[ -z "$ruby_ver" ]]   && ruby_ver=$_r
    [[ -z "$node_ver" ]]   && node_ver=$_n
    [[ -z "$python_ver" ]] && python_ver=$_p
    [[ -z "$php_ver" ]]    && php_ver=$_ph
  fi

  # nvm (shell function) can set the Node version; prefer it if available
  if [[ -z "$node_ver" ]] && command -v nvm &>/dev/null; then
    # `nvm current` outputs 'system' or 'none' or 'vX.Y.Z'
    local _nvm_out
    _nvm_out=$(nvm current 2>/dev/null || true)
    _nvm_out=${_nvm_out/#v/}
    if [[ -n "$_nvm_out" && "$_nvm_out" != "none" && "$_nvm_out" != "system" ]]; then
      node_ver="$_nvm_out"
    fi
  fi

  # rvm and rbenv take priority over mise/asdf for Ruby.
  if command -v rvm-prompt &>/dev/null; then
    ruby_ver=$(rvm-prompt i v g 2>/dev/null)
  elif command -v rbenv &>/dev/null; then
    ruby_ver=$(rbenv version-name 2>/dev/null)
  fi

  # System ruby.
  if [[ -z "$ruby_ver" ]] && command -v ruby &>/dev/null; then
    ruby_ver=$(ruby -v 2>/dev/null | awk '{print $2}')
  fi

  [[ -n "$ruby_ver" ]]   && versions+=" %F{#9B111E}[💎 rb-$ruby_ver]%f"
  [[ -n "$node_ver" ]]   && versions+=" %F{#417e38}[⬢ n-$node_ver]%f"
  [[ -n "$python_ver" ]] && versions+=" %F{#2b5b84}[🐍 py-$python_ver]%f"
  [[ -n "$php_ver" ]]    && versions+=" %F{#4F5B93}[🐘 php-$php_ver]%f"

  _tool_versions="$versions"
}

# Mark when a version-manager command is executed so we update versions
# on next prompt even if the PWD didn't change.
_tool_preexec() {
  local cmd
  cmd=${1%% *}
  case "$cmd" in
    mise|asdf|rvm|rbenv|ruby|node|nvm)
      _tool_pending_update=1
      ;;
  esac
}

# Populate on shell startup (precmd) and on every directory change (chpwd).
# The $PWD guard inside the function makes precmd a no-op when the directory is unchanged,
# but the preexec hook above sets `_tool_pending_update` so an in-place tool switch
# (e.g. `mise use`) will still cause an update on the next prompt.
add-zsh-hook chpwd _update_tool_versions
add-zsh-hook precmd _update_tool_versions
add-zsh-hook preexec _tool_preexec

local git_branch=' $(git_prompt_info)%{$reset_color%}'

PROMPT="${user_host} ${current_dir}"'${_tool_versions}'"${git_branch}
%B${user_symbol}%b "

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}[ "
ZSH_THEME_GIT_PROMPT_SUFFIX=" ] %{$reset_color%}"
