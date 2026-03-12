local user_host='%{$terminfo[bold]$fg[green]%}$(whoami)%{$reset_color%}'
local user_symbol='$'

local current_dir='%{$terminfo[bold]$fg[blue]%}%~%{$reset_color%}'

# Cache of tool versions — refreshed only when the current directory changes.
# Uses a single `asdf current` / `mise current` call instead of per-tool subprocess calls.
typeset -g _tool_versions=""
typeset -g _tool_versions_dir=""

_update_tool_versions() {
  [[ "$PWD" == "$_tool_versions_dir" ]] && return
  _tool_versions_dir="$PWD"

  local ruby_ver="" node_ver="" python_ver="" php_ver="" versions=""

  # Single mise call covers all active tools at once.
  # $2~/^[0-9]/ guards against "No version set" error messages.
  if command -v mise &>/dev/null; then
    local _mise_out
    _mise_out=$(mise current 2>/dev/null)
    ruby_ver=$(awk '$1=="ruby"   && $2~/^[0-9]/{print $2}' <<< "$_mise_out")
    node_ver=$(awk '$1=="node"   && $2~/^[0-9]/{print $2}' <<< "$_mise_out")
    python_ver=$(awk '$1=="python"&& $2~/^[0-9]/{print $2}' <<< "$_mise_out")
    php_ver=$(awk '$1=="php"     && $2~/^[0-9]/{print $2}' <<< "$_mise_out")
  fi

  # Single asdf call fills any gaps left by mise (or replaces it when mise is absent).
  if command -v asdf &>/dev/null && [[ -z "$ruby_ver" || -z "$node_ver" || -z "$python_ver" || -z "$php_ver" ]]; then
    local _asdf_out
    _asdf_out=$(asdf current 2>/dev/null)
    [[ -z "$ruby_ver" ]]   && ruby_ver=$(awk '$1=="ruby"   && $2~/^[0-9]/{print $2}' <<< "$_asdf_out")
    [[ -z "$node_ver" ]]   && node_ver=$(awk '$1=="nodejs" && $2~/^[0-9]/{print $2}' <<< "$_asdf_out")
    [[ -z "$python_ver" ]] && python_ver=$(awk '$1=="python"&& $2~/^[0-9]/{print $2}' <<< "$_asdf_out")
    [[ -z "$php_ver" ]]    && php_ver=$(awk '$1=="php"     && $2~/^[0-9]/{print $2}' <<< "$_asdf_out")
  fi

  # rvm and rbenv take priority over mise/asdf for Ruby.
  if command -v rvm-prompt &>/dev/null; then
    ruby_ver=$(rvm-prompt i v g 2>/dev/null)
  elif command -v rbenv &>/dev/null; then
    ruby_ver=$(rbenv version-name 2>/dev/null)
  fi

  # Last resort: system ruby.
  if [[ -z "$ruby_ver" ]] && command -v ruby &>/dev/null; then
    ruby_ver=$(ruby -v 2>/dev/null | awk '{print $2}')
  fi

  [[ -n "$ruby_ver" ]]   && versions+=" %F{#9B111E}[rb-$ruby_ver]%f"
  [[ -n "$node_ver" ]]   && versions+=" %F{#417e38}[n-$node_ver]%f"
  [[ -n "$python_ver" ]] && versions+=" %F{#2b5b84}[py-$python_ver]%f"
  [[ -n "$php_ver" ]]    && versions+=" %F{#4F5B93}[php-$php_ver]%f"

  _tool_versions="$versions"
}

# Populate on shell startup (precmd) and on every directory change (chpwd).
# The $PWD guard inside the function makes precmd a no-op when the directory is unchanged.
add-zsh-hook chpwd _update_tool_versions
add-zsh-hook precmd _update_tool_versions

local git_branch=' $(git_prompt_info)%{$reset_color%}'

PROMPT="${user_host} ${current_dir}"'${_tool_versions}'"${git_branch}
%B${user_symbol}%b "

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}[ "
ZSH_THEME_GIT_PROMPT_SUFFIX=" ] %{$reset_color%}"
