set -x LANG en_US.UTF-8
set -x KAFKAJS_NO_PARTITIONER_WARNING 1

# Node comes from nvm.fish (nvm_default_version). fish_add_path skips duplicates.
fish_add_path -g /Applications/flameshot.app/Contents/MacOS

# Static equivalent of `rbenv init - --no-rehash fish` (saves ~29ms per shell);
# the rbenv wrapper function is autoloaded from functions/rbenv.fish.
if status is-interactive
    fish_add_path -gm ~/.rbenv/shims
    set -gx RBENV_SHELL fish
end

# Git aliases
alias gp='git push origin HEAD'
alias gfo='git fetch origin'
alias gc='git checkout -'
alias gl='git log --oneline --graph --decorate'
alias gs='git status'
alias c='clear'

# Apps
alias codeit='code .;exit'
alias amboss='cd ~/amboss'
alias config='cd ~/.config/'

# System
alias ll='ls -la'