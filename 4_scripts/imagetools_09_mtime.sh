#!/bin/bash

################################################################################################

# File system check
# We don't allow writing to SD card.

#Sed is here to remove any trailing spaces and crap like blank lines
INPUT_FILESYSTEM=$(df -h "${1}" | awk -F ' ' 'FNR> 1 {print $1}' | grep -i -E "/dev/sd?|/dev/hd?|?rewritefs|?tmpfs|/dev/nvme?" | sed '/^\s*$/d' | wc -l)

if [[ "${INPUT_FILESYSTEM}" -eq 0 ]]; then #if input file (first file printed in bash) filesystem does not start with /dev/sdX
    kdialog --error "Image(s) are in a SD Card. Please move them your local or external storage and try again."
    exit
fi

################################################################################################


#We get the directory just from the first filename. Pwd should be easier, but bugged, so...
INPUT_DIR=$(dirname "${1}")
DIR_BASENAME=$(echo "${INPUT_DIR}" | rev | cut -d/ -f 1 | rev)

while [[ $# -gt 0 ]]; do

################################################################

# Values that change during the while loop (differ from file to file)

    INPUT="${1}"

    MTIME=$(exiftool -d "%s" -DateTimeOriginal -s -S "${INPUT}")
    touch --date=@${MTIME} "${INPUT}"

    shift # Move to the next file
done
