local user_host='%{$terminfo[bold]$fg[green]%}%n%{$reset_color%}'
local user_symbol='$'

# Parent-process cache for tool versions (formatted prompt fragment).
typeset -g _cleanzsh_versions=""
typeset -g _cleanzsh_versions_dir=""
typeset -g _cleanzsh_versions_disable=""
typeset -g _cleanzsh_pending=""
typeset -g _cleanzsh_async=0
# Bumped on invalidate; embedded in async payloads so in-flight workers
# from a previous generation cannot stick stale versions after mise/asdf/nvm.
typeset -gi _cleanzsh_gen=0
# Soft caps for manager stdout / async payload decode.
typeset -gi _cleanzsh_max_manager_lines=32
typeset -gi _cleanzsh_max_payload_bytes=4096

# Tool registry (display order). nodejs normalizes to node.
typeset -ga _cleanzsh_tools=(ruby node python php bun)
typeset -gA _cleanzsh_icon=(
  [ruby]=$'\ue739'
  [node]=$'\ued0d'
  [python]=$'\ue73c'
  [php]=$'\ue608'
  [bun]=$'\ue76f'
)
typeset -gA _cleanzsh_color=(
  [ruby]='#AE1401'
  [node]='#66CC33'
  [python]='#306998'
  [php]='#777BB3'
  [bun]='#FBF0DF'
)
typeset -gA _cleanzsh_label=(
  [ruby]=rb
  [node]=n
  [python]=py
  [php]=php
  [bun]=bun
)

# Scratch: _cleanzsh_v[tool]=version; _cleanzsh_disabled[tool]=1;
# _cleanzsh_payload_* = async decode scratch (not public cache contract).
typeset -gA _cleanzsh_v
typeset -gA _cleanzsh_disabled
typeset -g _cleanzsh_payload_dir="" _cleanzsh_payload_disable=""
typeset -g _cleanzsh_payload_gen="" _cleanzsh_payload_fmt=""

_cleanzsh_async_output_get() {
  REPLY="${_OMZ_ASYNC_OUTPUT[_cleanzsh_fetch_tool_versions]-}"
}

_cleanzsh_async_output_clear() {
  (( $+_OMZ_ASYNC_OUTPUT )) || typeset -gA _OMZ_ASYNC_OUTPUT
  _OMZ_ASYNC_OUTPUT[_cleanzsh_fetch_tool_versions]=""
}

# Map nodejs→node; allowlist only. Sets REPLY or returns 1.
_cleanzsh_normalize_tool_name() {
  local name=${(L)1}
  case "$name" in
    ruby|node|python|php|bun)
      REPLY=$name
      return 0
      ;;
    nodejs)
      REPLY=node
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Parse CLEANSH_DISABLE_VERSION into _cleanzsh_disabled (allowlisted names only).
_cleanzsh_disabled_tools() {
  setopt localoptions extendedglob
  _cleanzsh_disabled=()
  local item
  for item in ${(s:,:)CLEANSH_DISABLE_VERSION}; do
    item=${item##[[:space:]]#}
    item=${item%%[[:space:]]#}
    [[ -n "$item" ]] || continue
    _cleanzsh_normalize_tool_name "$item" || continue
    _cleanzsh_disabled[$REPLY]=1
  done
}

# Set REPLY backend name: mise | asdf | nvm | (empty). No subshell.
_cleanzsh_select_backend() {
  if (( $+commands[mise] || $+functions[mise] )); then
    REPLY=mise
  elif (( $+commands[asdf] || $+functions[asdf] )); then
    REPLY=asdf
  elif (( ! $+_cleanzsh_disabled[node] )) \
    && (( $+commands[nvm] || $+functions[nvm] )); then
    REPLY=nvm
  else
    REPLY=""
  fi
}

# Prefer shell function (activate wrappers), else binary via command.
_cleanzsh_run_manager_current() {
  local manager=$1
  if (( $+functions[$manager] )); then
    REPLY=$($manager current 2>/dev/null)
  elif (( $+commands[$manager] )); then
    REPLY=$(command "$manager" current 2>/dev/null)
  else
    REPLY=""
    return 1
  fi
  return 0
}

# Accept only safe version tokens (blocks PROMPT % escapes / junk / ESC).
# Sets REPLY to the sanitized version (without leading v) or returns 1.
_cleanzsh_sanitize_version() {
  setopt localoptions extendedglob
  local version=$1
  version=${version#v}
  # Reject control chars (ESC/OSC) and non-allowlisted tokens; cap length.
  [[ "$version" != *[[:cntrl:]]* ]] || return 1
  (( $#version >= 1 && $#version <= 64 )) || return 1
  [[ "$version" == [0-9][0-9A-Za-z._+-]# ]] || return 1
  REPLY=$version
  return 0
}

_cleanzsh_clear_versions_raw() {
  local tool
  for tool in ${_cleanzsh_tools[@]}; do
    _cleanzsh_v[$tool]=""
  done
}

_cleanzsh_all_tools_disabled() {
  local tool
  for tool in ${_cleanzsh_tools[@]}; do
    (( $+_cleanzsh_disabled[$tool] )) || return 1
  done
  return 0
}

# True when every non-disabled tool already has a version (stop parsing early).
_cleanzsh_collect_complete() {
  local tool
  for tool in ${_cleanzsh_tools[@]}; do
    (( $+_cleanzsh_disabled[$tool] )) && continue
    [[ -n "${_cleanzsh_v[$tool]}" ]] || return 1
  done
  return 0
}

# Collect versions into _cleanzsh_v[tool].
_cleanzsh_collect_versions() {
  _cleanzsh_clear_versions_raw
  _cleanzsh_all_tools_disabled && return

  local output line tool version rest backend
  local -i lines=0
  _cleanzsh_select_backend
  backend=$REPLY

  case "$backend" in
    mise|asdf)
      _cleanzsh_run_manager_current "$backend" || return
      output=$REPLY
      ;;
    nvm)
      version=$(nvm current 2>/dev/null || true)
      if [[ "$version" != "none" && "$version" != "system" ]] \
        && _cleanzsh_sanitize_version "$version"; then
        _cleanzsh_v[node]=$REPLY
      fi
      return
      ;;
    *)
      return
      ;;
  esac

  while IFS= read -r line; do
    (( ++lines > _cleanzsh_max_manager_lines )) && break
    # asdf prints extra columns (path, etc.); ignore them after version.
    read -r tool version rest <<< "$line"
    _cleanzsh_normalize_tool_name "$tool" || continue
    tool=$REPLY
    (( $+_cleanzsh_disabled[$tool] )) && continue
    _cleanzsh_sanitize_version "$version" || continue
    _cleanzsh_v[$tool]=$REPLY
    _cleanzsh_collect_complete && break
  done <<< "$output"
}

# Write formatted versions into _cleanzsh_versions (same shell, no $()).
_cleanzsh_format_versions() {
  local versions="" tool ver
  for tool in ${_cleanzsh_tools[@]}; do
    ver="${_cleanzsh_v[$tool]}"
    [[ -n "$ver" ]] || continue
    versions+=" %F{${_cleanzsh_color[$tool]}}[${_cleanzsh_icon[$tool]} ${_cleanzsh_label[$tool]}-$ver]%f"
  done
  _cleanzsh_versions="$versions"
}

# Payload: (dir, disable, gen, fmt). Four ${(qq)} fields, no trailing newline —
# OMZ reads with read -d '' and would keep \n, which breaks ${(z)} into 5 fields.
_cleanzsh_emit_payload() {
  print -rn -- ${(qq)1} ${(qq)2} ${(qq)3} ${(qq)4}
}

_cleanzsh_decode_payload() {
  emulate -L zsh
  setopt localoptions noksharrays
  local payload=${1%$'\n'}
  (( $#payload <= _cleanzsh_max_payload_bytes )) || return 1
  local -a parts
  parts=(${(z)payload})
  (( ${#parts} == 4 )) || return 1
  _cleanzsh_payload_dir=${(Q)parts[1]}
  _cleanzsh_payload_disable=${(Q)parts[2]}
  _cleanzsh_payload_gen=${(Q)parts[3]}
  _cleanzsh_payload_fmt=${(Q)parts[4]}
  [[ -n "$_cleanzsh_payload_dir" ]] || return 1
  return 0
}

# Shared dir + CLEANSH_DISABLE_VERSION match against current shell context.
_cleanzsh_context_matches() {
  [[ "$1" == "$PWD" && "$2" == "$CLEANSH_DISABLE_VERSION" ]]
}

_cleanzsh_cache_valid() {
  [[ -z "$_cleanzsh_pending" ]] \
    && _cleanzsh_context_matches "$_cleanzsh_versions_dir" \
      "$_cleanzsh_versions_disable"
}

_cleanzsh_payload_fresh() {
  _cleanzsh_context_matches "$_cleanzsh_payload_dir" \
    "$_cleanzsh_payload_disable" \
    && [[ "$_cleanzsh_payload_gen" == "$_cleanzsh_gen" ]]
}

# Decode async output and require freshness. Sets payload scratch on success.
_cleanzsh_read_fresh_payload() {
  _cleanzsh_async_output_get
  local payload=$REPLY
  [[ -n "$payload" ]] || return 1
  _cleanzsh_decode_payload "$payload" || return 1
  _cleanzsh_payload_fresh || return 1
  return 0
}

_cleanzsh_build_versions() {
  _cleanzsh_disabled_tools
  _cleanzsh_collect_versions
  _cleanzsh_format_versions
}

# OMZ async worker: stdout is the payload only (managers' stderr → /dev/null).
_cleanzsh_fetch_tool_versions() {
  if ! _cleanzsh_cache_valid; then
    _cleanzsh_build_versions
  fi
  # On cache hit, _cleanzsh_versions is already set in the parent and inherited.
  _cleanzsh_emit_payload "$PWD" "$CLEANSH_DISABLE_VERSION" "$_cleanzsh_gen" \
    "$_cleanzsh_versions"
}

# Apply async output to the parent cache. Must run in precmd (parent shell),
# before _omz_async_request forks the worker — never inside $() in PROMPT.
# Async display reads OMZ output only; parent cache is for worker inheritance.
_cleanzsh_apply_async_output() {
  (( _cleanzsh_async )) || return 0
  # Stable prompt: skip decode when parent cache already matches.
  _cleanzsh_cache_valid && return 0
  _cleanzsh_read_fresh_payload || return 0
  _cleanzsh_versions="$_cleanzsh_payload_fmt"
  _cleanzsh_versions_dir="$_cleanzsh_payload_dir"
  _cleanzsh_versions_disable="$_cleanzsh_payload_disable"
  _cleanzsh_pending=""
}

_cleanzsh_update_tool_versions_sync() {
  _cleanzsh_cache_valid && return
  _cleanzsh_versions_dir="$PWD"
  _cleanzsh_versions_disable="$CLEANSH_DISABLE_VERSION"
  _cleanzsh_pending=""
  _cleanzsh_build_versions
}

# Invalidate cheaply (chpwd / preexec). Bump gen so in-flight workers' payloads
# are rejected; clear async output so the prompt shows […] until refresh.
_cleanzsh_invalidate() {
  (( _cleanzsh_gen++ ))
  _cleanzsh_pending=1
  _cleanzsh_versions=""
  _cleanzsh_versions_dir=""
  _cleanzsh_versions_disable=""
  if (( _cleanzsh_async )); then
    _cleanzsh_async_output_clear
  fi
}

# Invalidate after mise/asdf/nvm. Loops: peel wrappers/env-assignments/--, then
# context-aware flags (sudo/env/nice arg-taking vs boolean); basename so
# /opt/.../mise matches.
_cleanzsh_preexec() {
  emulate -L zsh
  setopt localoptions noksharrays
  local -a tokens
  local tok wrapper progress last_opt
  tokens=(${(z)1})
  (( ${#tokens} )) || return

  while true; do
    progress=0
    while (( ${#tokens} )); do
      tok="${tokens[1]}"
      case "$tok" in
        command|noglob|exec|builtin|nocorrect|time|--|*=*)
          tokens=("${(@)tokens[2,-1]}")
          wrapper=""
          progress=1
          ;;
        sudo|env|nice)
          tokens=("${(@)tokens[2,-1]}")
          wrapper="$tok"
          progress=1
          ;;
        *)
          break
          ;;
      esac
    done

    while (( ${#tokens} )); do
      tok="${tokens[1]}"
      [[ "$tok" == -* ]] || break
      if [[ "$tok" == -- ]]; then
        tokens=("${(@)tokens[2,-1]}")
        wrapper=""
        progress=1
        break
      fi
      last_opt="${tok##*-}"
      last_opt="${last_opt[-1]}"
      case "$wrapper" in
        sudo)
          case "$last_opt" in
            u|g|h|p|C|D|R|T|t|c)
              if (( ${#tokens} > 1 )); then
                tokens=("${(@)tokens[3,-1]}")
              else
                tokens=("${(@)tokens[2,-1]}")
              fi
              ;;
            *)
              tokens=("${(@)tokens[2,-1]}")
              ;;
          esac
          ;;
        env)
          case "$last_opt" in
            u|C|S|a)
              if (( ${#tokens} > 1 )); then
                tokens=("${(@)tokens[3,-1]}")
              else
                tokens=("${(@)tokens[2,-1]}")
              fi
              ;;
            *)
              tokens=("${(@)tokens[2,-1]}")
              ;;
          esac
          ;;
        nice)
          if [[ "$last_opt" == n ]]; then
            if (( ${#tokens} > 1 )); then
              tokens=("${(@)tokens[3,-1]}")
            else
              tokens=("${(@)tokens[2,-1]}")
            fi
          else
            tokens=("${(@)tokens[2,-1]}")
          fi
          ;;
        *)
          tokens=("${(@)tokens[2,-1]}")
          ;;
      esac
      progress=1
    done

    (( progress )) || break
  done

  (( ${#tokens} )) || return
  tok="${tokens[1]}"
  tok="${tok##*/}"
  case "$tok" in
    mise|asdf|nvm)
      _cleanzsh_invalidate
      ;;
  esac
}

_cleanzsh_chpwd() {
  _cleanzsh_invalidate
}

# Prompt stub for async (runs inside $() — display only, no parent-cache writes).
_cleanzsh_tool_versions_prompt() {
  # Inherited parent cache avoids re-decoding OMZ output on stable prompts.
  if _cleanzsh_cache_valid; then
    print -r -- "$_cleanzsh_versions"
    return
  fi
  if _cleanzsh_read_fresh_payload; then
    print -r -- "$_cleanzsh_payload_fmt"
    return
  fi
  print -r -- ' %F{8}[…]%f'
}

# Keep apply-hook immediately before _omz_async_request so the worker inherits
# an up-to-date parent cache on cache hits. Best-effort at theme load only;
# later precmd reordering by other plugins is not re-checked mid-hook.
_cleanzsh_ensure_async_precmd_order() {
  emulate -L zsh
  setopt localoptions noksharrays unset
  (( _cleanzsh_async )) || return 0
  local -a rest
  local -i idx
  rest=(${precmd_functions:#_cleanzsh_apply_async_output})
  idx=${rest[(Ie)_omz_async_request]}
  if (( idx )); then
    precmd_functions=(
      ${rest[1,idx-1]}
      _cleanzsh_apply_async_output
      ${rest[idx,-1]}
    )
  else
    precmd_functions=(_cleanzsh_apply_async_output $rest)
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook -d chpwd _cleanzsh_chpwd
add-zsh-hook -d preexec _cleanzsh_preexec
add-zsh-hook -d precmd _cleanzsh_update_tool_versions_sync
add-zsh-hook -d precmd _cleanzsh_apply_async_output

add-zsh-hook chpwd _cleanzsh_chpwd
add-zsh-hook preexec _cleanzsh_preexec

local current_dir='%{$terminfo[bold]$fg[blue]%}%~%{$reset_color%}'
local git_branch=' $(git_prompt_info)%{$reset_color%}'

if (( $+functions[_omz_register_handler] )); then
  _cleanzsh_async=1
  add-zsh-hook precmd _cleanzsh_apply_async_output
  _omz_register_handler _cleanzsh_fetch_tool_versions
  _cleanzsh_ensure_async_precmd_order
  PROMPT="${user_host} ${current_dir}"'$(_cleanzsh_tool_versions_prompt)'"${git_branch}
%B${user_symbol}%b "
else
  _cleanzsh_async=0
  add-zsh-hook precmd _cleanzsh_update_tool_versions_sync
  # Sync path: expand cached fragment in the parent (no $() subshell).
  PROMPT="${user_host} ${current_dir}"'${_cleanzsh_versions}'"${git_branch}
%B${user_symbol}%b "
fi

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}[ "
ZSH_THEME_GIT_PROMPT_SUFFIX=" %{$fg[yellow]%}] %{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%F{red}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""
