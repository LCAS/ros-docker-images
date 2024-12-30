#!/bin/bash


set -xe
# hand over to nvidia if present
if [ -r /opt/nvidia/nvidia_entrypoint.sh ]; then
    exec /opt/nvidia/nvidia_entrypoint.sh "$@" 2>/tmp/entrypoint.log
else
    bash /opt/nvidia/entrypoint.d/90-turbovnc.sh 2>/tmp/entrypoint.log
    exec "$@"
fi
