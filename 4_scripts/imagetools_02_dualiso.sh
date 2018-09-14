#!/bin/bash 

#    Batch convert multiple Magic Lantern dual ISO image files on Linux
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

# NOTE: This script REQUIRES a patched cr2hdr tool with '--dry-run' parameter support!!
# Required patch file is provided in the same repository with this script

#Brackets and quotation marks in variables prevent errors occuring if file paths with spaces is used.

################################################################################################

# File system check
# We don't allow writing to SD card.

#Sed is here to remove any trailing spaces and crap like blank lines
INPUT_FILESYSTEM=$(df -h "${1}" | awk -F ' ' 'FNR> 1 {print $1}' | grep -i -E "/dev/sd?|/dev/hd?" | sed '/^\s*$/d' | wc -l)

if [[ "${INPUT_FILESYSTEM}" -eq 0 ]]; then #if input file (first file printed in bash) filesystem does not start with /dev/sdX
    kdialog --error "Image(s) are in a SD Card. Please move them your local or external storage and try again."
    exit
fi

################################################################################################

#We get the directory just from the first filename. Pwd should be easier, but bugged, so...
INPUT_DIR=$(dirname "${1}")
DIR_BASENAME=$(echo "${INPUT_DIR}" | rev | cut -d/ -f 1 | rev)

echo "DEBUG: Input dir is $INPUT_DIR"

mkdir -p "${INPUT_DIR}"/converted_dual_iso

echo "DEBUG: 'converted_dual_iso' directory created"

############################################################################################

####PROGRESSBAR STUFF - BEGIN
LABELTEXT='Processing RAW images...'
numargs=$# # Number of all files
tics=100 # Percentage tics
inc=0 # Current file number
mltp=1000 # Percentage multiplier for bash

dbusRef=$(kdialog --title "Dual ISO (folder: ${DIR_BASENAME})" --progressbar "$LABELTEXT" $tics)
qdbus $dbusRef showCancelButton true

####PROGRESSBAR STUFF - END

while [[ $# -gt 0 ]] && [[ $(qdbus $dbusRef wasCancelled) == "false" ]]; do

    INPUT="${1}" #Input file path, full path like: /home/myhome/IMG_4021.CR2
    OLDFILE_CR2=$(basename "${INPUT}") #Output as IMG_4021.CR2 (for example)

    # Once we do this, it's very clear which kind of CR2 file we're talking about here.
    NEWFILE_CR2=$(basename "${INPUT}" | sed 's/\.\w*$/_dualiso.CR2/') 

    # Converted Dual ISO file.
    NEWFILE_DNG=$(basename "${INPUT}" | sed 's/\.\w*$/_dualiso.DNG/') 

    #If converted Dual ISO exists already, we skip the conversion process. This passes only if the file doesn't exist.
    if [[ ! -e "${INPUT_DIR}"/converted_dual_iso/"${NEWFILE_DNG}" ]]; then

        if [[ $(cr2hdr --dry-run "${INPUT}" | grep "Interlaced ISO detected" | wc -l) == 1 ]]; then # Test an input file for Dual ISO.

            echo "Interlaced ISO detected: ${OLDFILE_CR2}"

            #Rename detected dual ISO CR2 file with a proper prefix (so that we can distinguish Dual ISO images from "normal" CR2 files)
            mv "${INPUT_DIR}"/"${OLDFILE_CR2}" "${INPUT_DIR}"/"${NEWFILE_CR2}"

            #Input we will use from this point is the renamed file, so we set INPUT variable to point to the renamed file.
            INPUT="${INPUT_DIR}"/"${NEWFILE_CR2}"

            cr2hdr --process "${INPUT}" # Process a valid input file.

            mv "${INPUT_DIR}"/"${NEWFILE_DNG}" "${INPUT_DIR}"/converted_dual_iso/ # Move converted Dual ISO.

            # Add Subject=Dual-ISO tag for every Dual ISO CR2 file.
            echo "Writing new EXIF/XMP tag Subject: Dual ISO CR2"
            exiftool -xmp:subject='Dual ISO CR2' "${INPUT_DIR}"/"${NEWFILE_CR2}" -overwrite_original

        fi
    fi

##############################################

    ####PROGRESSBAR STUFF - BEGIN
    let inc++

    #Percentage needs to be calculated like this due to bash rounding limitations...
    PERCENT_VALUE=$((($mltp*$tics)/(200*$numargs/$inc % 2 + $mltp*$numargs/$inc)))
    #Output: 20, 40, 59, 80, 100 etc.

    qdbus $dbusRef Set "" "value" $PERCENT_VALUE;
    qdbus $dbusRef setLabelText "$LABELTEXT ($inc/$numargs)";
    ####PROGRESSBAR STUFF - END

    shift #Process next CR2/DNG file...
done

##############################################

#Close processing window if cancelled event has been triggered.

####PROGRESSBAR STUFF - BEGIN
# If the process was cancelled, remove tmp file and exit the script.
if [[ ! $(qdbus $dbusRef wasCancelled) == "false" ]]; then
    exit
fi

##############################################

#Close processing window if not cancelled and processing finished.

qdbus $dbusRef close
####PROGRESSBAR STUFF - END

##############################################

if [ $(pgrep -x 'cr2hdr' | wc -l) == 0 ]; then
    notify-send 'Dual ISO' -i image-x-krita 'Conversion done!'
fi

############################################################################################

QUESTCOUNT=0 #Ask this question only once

#Dual ISO (Subject only defined in converted Dual ISO DNG images)
for i in $(find "${INPUT_DIR}" -maxdepth 1 -type f -iname "*.DNG"); do
    if [[ ! -z $(echo -n $i) ]] && [[ $(exiftool $i |grep --max-count=1 "Subject" | sed -e 's/.*: //g') == *"Dual-ISO"* ]] ; then

        if [[ $QUESTCOUNT == 0 ]]; then
            QUESTION=$(kdialog --yesno "More Dual ISO files detected in '$(echo ${INPUT_DIR} | rev | cut -d/ -f1 | rev)' main folder. Do you want to move these files into 'converted_dual_iso' folder?";)
            echo $QUESTION
            MOVEALL=true
            let QUESTCOUNT++
        else
            MOVEALL=false
        fi

        if [[ $MOVEALL == true ]]; then
            mv $i "${INPUT_DIR}"/converted_dual_iso/
            echo "DEBUG: all detected Dual ISO images moved to 'converted_dual_iso' folder"
        fi

    fi
done

############################################################################################

#If there are no files converted, we delete converted_dual_iso folder
if [[ $(ls "${INPUT_DIR}"/converted_dual_iso | wc -l) == 0 ]]; then
    rm -Rf "${INPUT_DIR}"/converted_dual_iso
    echo "DEBUG: 'converted_dual_iso' empty, so deleted"
fi

exit
