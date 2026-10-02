# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Safer file operations
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Useful listing aliases
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'

# Editors
alias vi='nvim'
alias vim='nvim'

# tmux
alias t='tmux'
alias tls='tmux list-sessions'
alias ta='tmux attach'
alias tn='tmux new-session'

# ============================================================
# Useful development aliases
# ============================================================

# ---------- General ----------
alias c='clear'
alias cls='clear'
alias reload='source ~/.bashrc'
alias bashrc='nvim ~/.bashrc'
alias path='echo "$PATH" | tr ":" "\n"'
alias ports='ss -tulnp'
alias disk='df -h'
alias mem='free -h'
alias myip='hostname -I'

# ---------- Navigation ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias cdrive='cd /mnt/c'
# Windows home folder (works for any Windows user name); cached so new shells stay fast
if [ -z "${WINHOME:-}" ]; then
    if [ -s "$HOME/.cache/winhome" ]; then WINHOME="$(cat "$HOME/.cache/winhome")"
    elif command -v cmd.exe >/dev/null 2>&1; then
        WINHOME="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null)"
        [ -n "$WINHOME" ] && mkdir -p "$HOME/.cache" && printf '%s' "$WINHOME" > "$HOME/.cache/winhome"
    fi
fi
export WINHOME
alias desktop='cd "$WINHOME/Desktop"'
alias downloads='cd "$WINHOME/Downloads"'
alias kit='cd "${KIT_DIR:-$HOME/kits/reference_files}"'

mkcd() {
    mkdir -p -- "$1" && cd -- "$1"
}

# ---------- ls ----------
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -alFht'
alias lsize='ls -alFhS'

# ---------- Safer file operations ----------
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# ---------- Neovim ----------
alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias nv='nvim'
alias nvimconfig='nvim ~/.config/nvim/init.lua'
alias nvimclean='nvim --clean'
alias nvimlog='nvim ~/.local/state/nvim/log'

# Open current directory in Neovim
alias vhere='nvim .'

# ---------- tmux ----------
alias t='tmux'
alias tls='tmux list-sessions'
alias ta='tmux attach'
alias tn='tmux new-session'
alias tk='tmux kill-session'
alias tka='tmux kill-server'

# Create or attach to named session
tdev() {
    tmux new-session -A -s "${1:-dev}"
}

# ---------- Git ----------
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gds='git diff --staged'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gsw='git switch'
alias gnew='git switch -c'
alias glog='git log --oneline --graph --decorate --all'
alias glast='git log -1 --stat'
alias gundo='git reset --soft HEAD~1'
alias gstash='git stash'
alias gstashpop='git stash pop'

# ---------- Tar and archives ----------
alias targz='tar -czvf'
alias untargz='tar -xzvf'
alias tarlist='tar -tvf'
alias zipdir='zip -r'
alias unziphere='unzip'

extract() {
    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi

    case "$1" in
        *.tar.gz|*.tgz) tar -xzvf "$1" ;;
        *.tar.bz2)      tar -xjvf "$1" ;;
        *.tar.xz)       tar -xJvf "$1" ;;
        *.tar)          tar -xvf "$1" ;;
        *.zip)          unzip "$1" ;;
        *.gz)           gunzip "$1" ;;
        *.bz2)          bunzip2 "$1" ;;
        *.xz)           unxz "$1" ;;
        *.7z)           7z x "$1" ;;
        *)
            echo "Unsupported archive: $1"
            return 1
            ;;
    esac
}

# ---------- WSL / Windows ----------
alias explorer='explorer.exe .'
alias codehere='code .'
alias clip='clip.exe'
alias winpwd='wslpath -w "$(pwd)"'

# Open a file or directory in Windows Explorer
wopen() {
    if [[ $# -eq 0 ]]; then
        explorer.exe .
    else
        explorer.exe "$(wslpath -w "$1")"
    fi
}

# ---------- Process utilities ----------
alias psg='ps aux | grep -i'
alias topcpu='ps aux --sort=-%cpu | head'
alias topmem='ps aux --sort=-%mem | head'
alias jobsall='jobs -l'

# ---------- Networking ----------
alias pingg='ping google.com'
alias listening='ss -tuln'
alias curlhead='curl -I'

# ---------- Package management ----------
alias update='sudo apt update'
alias upgrade='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias cleanup='sudo apt autoremove && sudo apt autoclean'

# ---------- WezTerm ----------
alias wezconfig='nvim ~/.wezterm.lua'
alias wezreload='wezterm cli reload-config'
alias wezls='wezterm cli list'
alias weznew='wezterm cli spawn'

# ---------- History ----------
alias h='history'
alias hg='history | grep'
alias cc='claude'
export BROWSER="/mnt/c/Windows/explorer.exe"
