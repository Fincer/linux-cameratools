#!/bin/env bash

while [[ $# -gt 0 ]]
do
    INPUT="${1}"
    MTIME=$(exiftool -d "%s" -DateTimeOriginal -s -S "${INPUT}")
    if [[ ! -z "${MTIME}" ]]; then
      touch --date=@${MTIME} "${INPUT}"
    fi

    # Move to the next file.
    shift
done
