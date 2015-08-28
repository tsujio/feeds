#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

echo "[`date`] Start..."

curl -X POST --user $1:$2 -d force=true http://localhost/update_channels

echo "[`date`] End."
