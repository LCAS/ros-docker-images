#!/bin/bash


#set -ex

# adopted from /opt/nvidia/nvidia-entrypoint.sh

# Gather parts in alpha order
shopt -s nullglob extglob
#_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

_SCRIPT_DIR="/opt/nvidia"

declare -a _PARTS=( "${_SCRIPT_DIR}/entrypoint.d"/*@(.txt|.sh) )
shopt -u nullglob extglob

print_repeats() {
  local -r char="$1" count="$2"
  local i
  for ((i=1; i<=$count; i++)); do echo -n "$char"; done
  echo >&2
}

print_banner_text() {
  # $1: Banner char
  # $2: Text
  local banner_char=$1
  local -r text="$2"
  local pad="${banner_char}${banner_char}"
  print_repeats "${banner_char}" $((${#text} + 6))
  echo "${pad} ${text} ${pad}" >&2
  print_repeats "${banner_char}" $((${#text} + 6))
}

# Execute the entrypoint parts
for _file in "${_PARTS[@]}"; do
  case "${_file}" in
    *.txt) cat "${_file}" >&2;;
    *.sh)  source "${_file}" >&2;;
  esac
done

echo >&2

# This script can either be a wrapper around arbitrary command lines,
# or it will simply exec bash if no arguments were given
if [[ $# -eq 0 ]]; then
  exec "/bin/bash"
else
  exec "$@"
fi






# hand over to nvidia if present
# if [ -r /opt/nvidia/nvidia_entrypoint.sh ]; then
#     exec /opt/nvidia/nvidia_entrypoint.sh "$@"
# else
#     bash /opt/nvidia/entrypoint.d/90-turbovnc.sh
#     exec "$@"
# fi
