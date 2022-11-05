#!/bin/bash
export DECONZ_DEVICE=/dev/ttyZigBee
export DECONZ_HTTP_PORT=780
export DECONZ_WS_PORT=7443
REALDEV=$(readlink -f /dev/ttyZigBee)
echo  "Found real device in ${REALDEV}"
