#!/bin/bash

#    Delete critical metadata from an image or images using Exiftool
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

#kdialog --yesnocancel "Do you really want to delete EXIF data for the selection?";

#if [ "$?" = 0 ]; then
    while [ $# -gt 0 ]; do

        EXTENSION=$(echo $1 | rev | cut -f 1 -d '.' | rev) #Get the correct file extension for an input file (so the new one will use the same)

        FILE=$(basename $1 | sed "s/\.\w*$/.$EXTENSION/")

        exiftool -xmp:subject= -Software= -Version= -creatortool= -historysoftwareagent= -PhotoshopThumbnail= -FocalLength= -Lens= -FNumber= -ApertureValue= -LensInfo= -LensModel= -ExposureTime= -MaxApertureValue= -SerialNumber= -Make= -ExposureMode= -WhiteBalance= -Flash= -MeteringMode= -ExposureCompensation= -ShutterSpeedValue= -RecommendedExposureIndex= -SensitivityType= -LensSerialNumber= -FocalPlaneYResolution= -FocalPlaneXResolution= -FocalPlaneResolutionUnit= -XResolution= -YResolution= -ResolutionUnit= -iso= -ColorSpace= -Model= -ExposureProgram= -adobe:all= -xmp:all= -photoshop:all= $INPUT_DIR/$FILE -overwrite_original
        shift
    done
#    kdialog --msgbox "Exif metadata deleted!"
#else
#	exit 0
#fi
