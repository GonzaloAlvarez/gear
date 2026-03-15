
__COMMANDS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for i in $__COMMANDS_PATH/com/*; do
    alias $(basename $i)="${__COMMANDS_PATH}/run $(basename $i)"
done

for i in $__COMMANDS_PATH/util/*; do
    alias $(basename $i)="${i}"
done

alias gearconf="${__COMMANDS_PATH}/gearconf"
