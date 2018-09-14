#!/bin/bash

#    Extract DNG frames from Magic Lantern MLV files (KDE/Plasma DE)
#    Copyright (C) 2017  Pekka Helenius
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

#We get the directory just from the first filename. Pwd should be easier, but bugged, so...
INPUT_DIR=$(dirname $1)

mkdir -p $INPUT_DIR/mlv_export

while [ $# -gt 0 ]; do
    MLV=$1
    mlv_dump --dng $MLV -o ${MLV}_
    mv ????????.MLV_??????.dng $INPUT_DIR/mlv_export
    shift
done

kdialog --msgbox "MLV extracted successfully" --title "MLV Extraction";
