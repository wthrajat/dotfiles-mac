if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -x LANG en_US.UTF-8
set -x KAFKAJS_NO_PARTITIONER_WARNING 1

set PATH /Users/rajat/.nvm/versions/node/v23.3.0/bin $PATH
set PATH /opt/homebrew/Caskroom/flameshot/12.1.0/flameshot.app/Contents/MacOS/ $PATH

# Added by `rbenv init` on Fri Dec  6 23:13:12 IST 2024
status --is-interactive; and rbenv init - --no-rehash fish | source