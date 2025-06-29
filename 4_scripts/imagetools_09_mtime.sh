#!/bin/env bash

set -e
set -u

#    Replace file mtime value with DateTimeOriginal timestamp.
#    Copyright (C) 2025  Pekka Helenius
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

exit 0
