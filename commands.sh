
__COMMANDS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for i in $__COMMANDS_PATH/com/*; do
    alias $(basename $i)="${__COMMANDS_PATH}/run $(basename $i)"
done
