#!/bin/env bash

# set -e
# set -u

#    Delete all exif metadata from selected images with Exiftool
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

for INPUT in "${@}"
do

  INPUT_DIR=$(dirname "${INPUT_DIR}")
  mkdir -p "${INPUT_DIR}"/no_metadata

  # Get the correct file extension for an input file, to be used for the new file.
  EXTENSION=$(echo "${INPUT}" | rev | cut -f 1 -d '.' | rev)

  OLD_FILE=$(basename "${INPUT}" | sed "s/\.\w*$/.$EXTENSION/")
  NEW_FILE=$(basename "${OLD_FILE}" | sed "s/\.\w*$/_no_metadata.$EXTENSION/")

  exiftool -all= "${INPUT_DIR}/${OLD_FILE}" -o "${INPUT_DIR}/no_metadata/${NEW_FILE}"

  # Move to the next file.
  shift

done

exit 0
