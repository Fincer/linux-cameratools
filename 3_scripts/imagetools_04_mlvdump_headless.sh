#!/bin/env bash

set -e
set -u

#    Extract DNG frames from Magic Lantern MLV files (KDE/Plasma DE)
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

for MLV_FILE in "${@}"
do

  INPUT_DIR=$(dirname "${MLV_FILE}")

  mlv_dump --dng "${MLV_FILE}" -o "${MLV_FILE}_"

  if [[ ! -d "${INPUT_DIR}/mlv_export" ]]
  then
    mkdir -p "${INPUT_DIR}/mlv_export"
  fi

  mv ????????.MLV_??????.dng "${INPUT_DIR}/mlv_export"/

done

exit 0
