#!/bin/bash

#    Stack TIFF images with Anti-Lamenessing Engine (ALE)
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

#First & Last file names (without suffixes)
for last; do true; done
FIRST=$(basename $1 | cut -f 1 -d '.' | sed 's/IMG_//g') #Name of the first file passed into the script
LAST=$(basename $last | cut -f 1 -d '.' | sed 's/IMG_//g') #Name of the last file passed into the script



echo 'Starting image stacking process using temporary TIFF files.' && \
ale ./temp_tiff/*.tiff output.tif
