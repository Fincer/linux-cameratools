#!/bin/env bash

#set -e
#set -u

#    Batch convert CR2 files to DNG on Linux, considering
#    single ISO and Magic Lantern dual ISO CR2 image formats.
#
#    Copyright (C) 2017, 2023, 2025  Pekka Helenius
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    as published by the Free Software Foundation; either version 2
#    of the License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
###############################################

# We get the directory just from the first filename.
INPUT_DIR=$(dirname "${1}")
DIR_BASENAME=$(echo "${INPUT_DIR}" | rev | cut -d/ -f 1 | rev)

mkdir -p "${INPUT_DIR}/converted_dng"

on_exit() {
  # If there are no files, we delete converted_dng folder
  if [[ $(ls -w1 "${INPUT_DIR}/converted_dng" | wc -l) -eq 0 ]]
  then
    rm -Rf "${INPUT_DIR}/converted_dng"
  fi
}

trap on_exit ERR EXIT

############################################################################################

# PROGRESSBAR CODE - BEGIN

LABELTEXT="Processing RAW images..."
numargs=$# # Number of all files
tics=100   # Percentage tics
inc=0      # Current file number
mltp=1000  # Percentage multiplier for bash

dbusRef=$(kdialog --title "CR2 to DNG (folder: ${DIR_BASENAME})" --progressbar "${LABELTEXT}" "${tics}")
qdbus $dbusRef showCancelButton true

qdbus $dbusRef Set "" "value" "0"
qdbus $dbusRef setLabelText "$LABELTEXT (0/${numargs})"

# PROGRESSBAR CODE - END

while \
  [[ $# -gt 0 ]] && \
  [[ $(qdbus $dbusRef wasCancelled) == "false" ]]
do

  # PROGRESSBAR CODE - BEGIN
  let inc++

  # Percentage needs to be calculated like this due to bash rounding limitations.
  PERCENT_VALUE=$(((${mltp}*${tics})/(200*${numargs}/${inc} % 2 + ${mltp}*${numargs}/${inc})))
  # Output: 20, 40, 59, 80, 100 etc.

  qdbus $dbusRef Set "" "value" "${PERCENT_VALUE}"
  qdbus $dbusRef setLabelText "$LABELTEXT (${inc}/${numargs})"

  # PROGRESSBAR CODE - END

  INPUT="${1}"

  # NOTE: This check depends on MIME types known by the system.
  if [[ ! $(file -b --mime-type "${INPUT}" | tr '[:upper:]' '[:lower:]') == "image/x-canon-cr2" ]]
  then
    echo "${INPUT}: not a CR2 file."
    shift
    continue
  fi

  OLDFILE_CR2=$(basename "${INPUT}")

  # Get original modification time
  MTIME=$(exiftool -d "%s" -DateTimeOriginal -s -S "${INPUT}")

  # Test an input file for dual ISO.
  if [[ $(cr2hdr --dry-run "${INPUT}") =~ Interlaced\ ISO\ detected ]]
  then

    echo "Interlaced ISO detected: ${OLDFILE_CR2}"

    NEWFILE_CR2=$(basename "${INPUT}" | sed 's/_dualiso// ;s/\.\w*$/_dualiso.CR2/')

    # Converted dual ISO file.
    NEWFILE_DNG=$(basename "${INPUT}" | sed 's/_dualiso// ;s/\.\w*$/_dualiso.DNG/')

    # If converted dual ISO exists already, we skip the conversion process.
    # NOTE: This is not a robust check.
    if [[ -f "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}" ]]
    then
      echo "${INPUT}: already converted ('${DIR_BASENAME}/converted_dng/${NEWFILE_DNG}')."
      shift
      continue
    fi

    # Copy detected dual ISO CR2 file to a new file with a proper prefix & suffix.
    cp -pf "${INPUT_DIR}/${OLDFILE_CR2}" "${INPUT_DIR}/.${NEWFILE_CR2}"

    # Process a valid input file.
    # Bypass rest of the processing of this file, if error encountered.
    if ! cr2hdr --process "${INPUT_DIR}/.${NEWFILE_CR2}"
    then
      rm -f "${INPUT_DIR}/.${NEWFILE_CR2}"
      rm -f "${INPUT_DIR}/.${NEWFILE_DNG}"
      shift
      continue
    fi

    # Delete original CR2.
    if [[ -f "${INPUT_DIR}/.${NEWFILE_CR2}" ]]
    then
      rm -f "${INPUT_DIR}/${OLDFILE_CR2}"
    fi

    # Rename CR2 file.
    mv -f "${INPUT_DIR}/.${NEWFILE_CR2}" "${INPUT_DIR}/${NEWFILE_CR2}"

    # Move & rename converted dual ISO DNG file.
    mv -f "${INPUT_DIR}/.${NEWFILE_DNG}" "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}"

    # Add "Subject=Dual ISO CR2" tag for every Dual ISO file (CR2+DNG).
    echo "Writing new EXIF/XMP tag Subject: Dual ISO CR2"
    exiftool -xmp:subject="Dual ISO CR2" "${INPUT_DIR}/${NEWFILE_CR2}" -overwrite_original
    exiftool -xmp:subject="Dual ISO CR2" "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}" -overwrite_original

    # Restore original modification time.
    if [[ ! -z "${MTIME}" ]]
    then
      touch --date=@${MTIME} "${INPUT_DIR}/${NEWFILE_CR2}"
      touch --date=@${MTIME} "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}"
    fi

  # Else: this is a normal CR2 file. Convert to regular DNG
  else

    NEWFILE_CR2=$(basename "${INPUT}" | sed 's/_singleiso// ;s/\.\w*$/_singleiso.CR2/')

    # Converted single ISO file.
    NEWFILE_DNG=$(basename "${INPUT}" | sed 's/_singleiso// ;s/\.\w*$/_singleiso.DNG/')

    # If converted single ISO exists already, we skip the conversion process.
    # NOTE: This is not a robust check.
    if [[ -f "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}" ]]
    then
      echo "${INPUT}: already converted ('${DIR_BASENAME}/converted_dng/${NEWFILE_DNG}')."
      shift
      continue
    fi

    # Copy single ISO CR2 file to a new file with a proper prefix & suffix.
    cp -pf "${INPUT_DIR}/${OLDFILE_CR2}" "${INPUT_DIR}/.${NEWFILE_CR2}"

    # Process a valid input file. dnglab may end up with a lowercase suffix.
    # Bypass rest of the processing of this file, if error encountered.
    if ! dnglab convert "${INPUT_DIR}/.${NEWFILE_CR2}" "${INPUT_DIR}/.${NEWFILE_DNG}"
    then
      rm -f "${INPUT_DIR}/.${NEWFILE_CR2}"
      rm -f "${INPUT_DIR}/.${NEWFILE_DNG}"
      shift
      continue
    fi

    # Delete original CR2.
    if [[ -f "${INPUT_DIR}/.${NEWFILE_CR2}" ]]
    then
      rm -f "${INPUT_DIR}/${OLDFILE_CR2}"
    fi

    # Rename CR2 file.
    mv -f "${INPUT_DIR}/.${NEWFILE_CR2}" "${INPUT_DIR}/${NEWFILE_CR2}"

    # Convert possible lowercase suffix to uppercase.
    find "${INPUT_DIR}" -maxdepth 1 -type f -iname ".${NEWFILE_DNG}" |
      xargs -I {} mv {} ".${NEWFILE_DNG}"

    # Move converted single ISO file.
    mv -f "${INPUT_DIR}/.${NEWFILE_DNG}" "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}"

    # Add "Subject=Single ISO CR2" tag for every Single ISO CR2 file.
    echo "Writing new EXIF/XMP tag Subject: Single ISO CR2"
    exiftool -xmp:subject="Single ISO CR2" "${INPUT_DIR}/${NEWFILE_CR2}" -overwrite_original
    exiftool -xmp:subject="Single ISO CR2" "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}" -overwrite_original

    # Restore original modification time.
    if [[ ! -z "${MTIME}" ]]
    then
      touch --date=@${MTIME} "${INPUT_DIR}/${NEWFILE_CR2}"
      touch --date=@${MTIME} "${INPUT_DIR}/converted_dng/${NEWFILE_DNG}"
    fi

  fi

##############################################

  # Move to the next file.
  shift

done

##############################################

# Close processing window if cancelled event has been triggered.

# PROGRESSBAR CODE - BEGIN

# If the process was cancelled, remove tmp file and exit the script.
if [[ ! $(qdbus $dbusRef wasCancelled) == "false" ]]
then
  exit 0
fi

# Close processing window if not cancelled and processing finished.

qdbus $dbusRef close

# PROGRESSBAR CODE - END

##############################################

if \
  [[ $(pgrep -x 'cr2hdr' | wc -l) -eq 0 ]] &&
  [[ $(pgrep -x 'dnglab' | wc -l) -eq 0 ]]
then
  notify-send 'CR2 to DNG' -i image-x-krita 'Conversion done!'
fi

############################################################################################

MOVE_ALL=0

# Move already converted single & dual ISO DNGs if detected in INPUT_DIR
# (Subject field is only defined in converted single & dual ISO DNG images)
for i in $(find "${INPUT_DIR}" -maxdepth 1 -type f -iname "*.DNG")
do
  subjects=(
    $(exiftool "${i}" | awk -F: 'BEGIN{IGNORECASE=1}/^Subject\s+:/ { {gsub(/^\s+/,"",$2); print $2} }')
  )
  for j in ${subjects[@]}
  do
    if [[ ${j} =~ (Dual|Single)\ ISO\ CR2 ]]
    then

      if [[ ${MOVE_ALL} -eq 0 ]]
      then
        QUESTION=$(kdialog --yesno "More single or dual ISO files detected in '${DIR_BASENAME}' main folder. Do you want to move these files into 'converted_dng' folder?";)
        echo "${QUESTION}"
        MOVE_ALL=1
      else
        mv "${i}" "${INPUT_DIR}/converted_dng/"
      fi
      break
    fi
  done
done

#if [[ "${MOVE_ALL}" -eq 1 ]]
#then
#  echo "DEBUG: all detected single & dual ISO images moved to 'converted_dng' folder"
#fi

############################################################################################

exit 0
