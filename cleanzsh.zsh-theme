local user_host='%{$terminfo[bold]$fg[green]%}$(whoami)%{$reset_color%}'
local user_symbol='$'

local current_dir='%{$terminfo[bold]$fg[blue]%}%~%{$reset_color%}'

get_ruby_version() {
  local ruby=''

  if which rvm-prompt &> /dev/null; then
    ruby="$(rvm-prompt i v g)"
  elif which rbenv &> /dev/null; then
    ruby="$(rbenv version-name)"
  elif which asdf &> /dev/null; then
    asdf_ruby_ver=$(asdf current ruby | awk '/ruby/{p=1} NF{out=$2} END{if(p==1){print out}}')
    ruby="$asdf_ruby_ver"
  elif which mise &> /dev/null; then
    mise_ruby_ver=$(mise current ruby 2>/dev/null)
    if [[ "$mise_ruby_ver" != *WARN* && -n "$mise_ruby_ver" ]]; then
      ruby="$mise_ruby_ver"
    fi
  elif which ruby &> /dev/null; then
    ruby_ver=$(ruby -v 2>/dev/null | awk '{print $2}')
    ruby="$ruby_ver"
  fi

  if [[ -n "$ruby" ]]; then
    echo -n " %F{#9B111E}[rb-$ruby]%f"
  fi
}

get_node_version() {
  local node=''

  if which asdf &> /dev/null; then
    asdf_node_ver=`asdf current nodejs | awk '/nodejs/{p=1} NF{out=$2} END{if(p==1){print out}}'`
    node="$asdf_node_ver"
  elif which mise &> /dev/null; then
    mise_node_ver=$(mise current node 2>/dev/null)
    if [[ "$mise_node_ver" != *WARN* && -n "$mise_node_ver" ]]; then
      node="$mise_node_ver"
    fi
  fi

  if [[ -n "$node" ]]; then
    echo -n " %F{#417e38}[n-$node]%f"
  fi
}

get_python_version() {
  local python=''

  if which asdf &> /dev/null; then
    asdf_python_ver=`asdf current python | awk '/python/{p=1} NF{out=$2} END{if(p==1){print out}}'`
    python="$asdf_python_ver"
  elif which mise &> /dev/null; then
    mise_python_ver=$(mise current python 2>/dev/null)
    if [[ "$mise_python_ver" != *WARN* && -n "$mise_python_ver" ]]; then
      python="$mise_python_ver"
    fi
  fi

  if [[ -n "$python" ]]; then
    echo -n " %F{#2b5b84}[py-$python]%f"
  fi
}

get_php_version() {
  local php=''

  if which asdf &> /dev/null; then
    asdf_php_ver=`asdf current php | awk '/php/{p=1} NF{out=$2} END{if(p==1){print out}}'`
    php="$asdf_php_ver"
  elif which mise &> /dev/null; then
    mise_php_ver=$(mise current php 2>/dev/null)
    # Se a saída contiver 'WARN', ignora
    if [[ "$mise_php_ver" != *WARN* && -n "$mise_php_ver" ]]; then
      php="$mise_php_ver"
    fi
  fi

  if [[ -n "$php" ]]; then
    echo -n " %F{#4F5B93}[php-$php]%f"
  fi
}

local git_branch=' $(git_prompt_info)%{$reset_color%}'

PROMPT="${user_host} ${current_dir}$(get_ruby_version)$(get_node_version)$(get_python_version)$(get_php_version)${git_branch}
%B${user_symbol}%b "

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}[ "
ZSH_THEME_GIT_PROMPT_SUFFIX=" ] %{$reset_color%}"
