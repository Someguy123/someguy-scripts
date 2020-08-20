######################
#
# kphoen-lite.zsh-theme
#
# Original dev unknown. Original theme: https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/kphoen.zsh-theme
#
# The kphoen-lite fork was written by Someguy123 - https://github.com/Someguy123
#
# Installation: 
#   save file into ~/.oh-my-zsh/custom/themes/kphoen-lite.zsh-theme
#   or globally: /etc/oh-my-zsh/custom/themes/kphoen-lite.zsh-theme
#
# Modified fork of kphoen.zsh-theme with single line prompt, prompt timestamp,
# and removed username.
#
# Username can optionally be re-enabled simply by setting:
#
#   SHOW_PROMPT_USER=1
#
# early in your .zshrc before the theme is loaded.
#
# Prompt looks like:
#
#     (cyan)     (magenta)    (blue)
#   [03:26:54] [some-server /usr/share] #
#
#     (cyan)     (magenta)    (blue)      (green)
#   [03:26:54] [some-server ~/myproject on master] #
#
# With SHOW_PROMPT_USER=1 :
#
#   (cyan)     (red)   (magenta)    (blue)      (green)
#   [03:38:40] [ubuntu@some-server ~/myproject on master] %
#
######################

: ${SHOW_PROMPT_USER=0}

if [[ "$TERM" != "dumb" ]] && [[ "$DISABLE_LS_COLORS" != "true" ]]; then
    PROMPT='%{$fg[red]%}[%{$fg[cyan]%}%D{%H:%M:%S}%{$fg[red]%}] %{$fg[yellow]%}['
    #PROMPT='[%{$fg[cyan]%}%D{%H:%M:%S}%{$reset_color%}] ['
    if (( SHOW_PROMPT_USER )); then
        PROMPT+='%{$fg[red]%}%n%{$reset_color%}@'
    fi
    PROMPT+='%{$fg[magenta]%}%m %{$fg[blue]%}%~%{$reset_color%}$(git_prompt_info)%{$fg[yellow]%}] %{$fg[red]%}%#%{$reset_color%} '

    ZSH_THEME_GIT_PROMPT_PREFIX=" on %{$fg[green]%}"
    ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
    ZSH_THEME_GIT_PROMPT_DIRTY="" ZSH_THEME_GIT_PROMPT_CLEAN=""

    # display exitcode on the right when >0
    return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

    RPROMPT='${return_code}$(git_prompt_status)%{$reset_color%}'

    ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} ✚"
    ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%} ✹"
    ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} ✖"
    ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%} ➜"
    ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%} ═"
    ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} ✭"
else
    PROMPT='[%n@%m:%~$(git_prompt_info)] %# '

    ZSH_THEME_GIT_PROMPT_PREFIX=" on"
    ZSH_THEME_GIT_PROMPT_SUFFIX="" ZSH_THEME_GIT_PROMPT_DIRTY="" ZSH_THEME_GIT_PROMPT_CLEAN=""

    # display exitcode on the right when >0
    return_code="%(?..%? ↵)"

    RPROMPT='${return_code}$(git_prompt_status)'

    ZSH_THEME_GIT_PROMPT_ADDED=" ✚"
    ZSH_THEME_GIT_PROMPT_MODIFIED=" ✹"
    ZSH_THEME_GIT_PROMPT_DELETED=" ✖"
    ZSH_THEME_GIT_PROMPT_RENAMED=" ➜"
    ZSH_THEME_GIT_PROMPT_UNMERGED=" ═"
    ZSH_THEME_GIT_PROMPT_UNTRACKED=" ✭"
fi

