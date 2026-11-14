# Wrapper from `rbenv init - fish`: `rbenv shell` and `rbenv rehash` must run in this shell.
function rbenv
    set -l command $argv[1]
    set -e argv[1]

    switch "$command"
        case rehash shell
            command rbenv "sh-$command" $argv | source
        case '*'
            command rbenv "$command" $argv
    end
end
