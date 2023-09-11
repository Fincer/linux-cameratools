#!/bin/env bash

#    Delete all exif metadata from selected images with Exiftool
#    Copyright (C) 2017,2023  Pekka Helenius
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

mkdir -p "${INPUT_DIR}"/nometadata

#kdialog --yesnocancel "Do you really want to delete EXIF data for the selection?";

#if [[ "$?" = 0 ]]
#then
  while [[ $# -gt 0 ]]
  do

    # Get the correct file extension for an input file, to be used for the new file.
    EXTENSION=$(echo "${1}" | rev | cut -f 1 -d '.' | rev)

    OLDFILE=$(basename "${1}" | sed "s/\.\w*$/.$EXTENSION/")
    NEWFILE=$(basename "$OLDFILE" | sed "s/\.\w*$/_nometadata.$EXTENSION/")

    exiftool -all= "${INPUT_DIR}/${OLDFILE}" -o "${INPUT_DIR}/nometadata/${NEWFILE}"

    # Move to the next file.
    shift
  done
# else
#   exit 0
# fi

# Delete empty metadata folder.
if [[ $(ls "${INPUT_DIR}/nometadata/" | wc -l) == 0 ]]
then
  rm -Rf "${INPUT_DIR}/nometadata/"
fi
