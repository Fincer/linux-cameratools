#!/bin/env bash

#    Add CR2 tags: Baseline, Subject (to distinguish Single & Dual ISOs)
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
DIR_BASENAME=$(echo "${INPUT_DIR}" | rev | cut -d/ -f 1 | rev)

# Camera resolution in pixels (absolute limit, we can't exceed these pixel values!)
C5DMK3_WIDTH=5796
C5DMK3_HEIGHT=3870

# In a case or emergency (can't open a picture etc), revert these values to 5760 x 3840.

################################################################################################

# PROGRESSBAR CODE - BEGIN

LABELTEXT="Processing RAW images..."
numargs=$# # Number of all files
tics=100   # Percentage tics
inc=0      # Current file number
mltp=1000  # Percentage multiplier for bash

dbusRef=$(
  kdialog \
    --title "EXIF Tags (folder: ${DIR_BASENAME})" \
    --progressbar "$LABELTEXT" "${tics}"
)

qdbus $dbusRef showCancelButton true

# PROGRESSBAR CODE - END

while \
  [[ $# -gt 0 ]] && \
  [[ $(qdbus $dbusRef wasCancelled) == "false" ]]
do

################################################################

  # Values that change during the while loop (differ from file to file)

  INPUT="${1}"
  INPUT_MTIME=$(stat -c "%Y" "${INPUT}")

  INPUT_BASENAME=$(basename "${INPUT}" | cut -f 1 -d '.')

  # Get the correct file extension for an input file, to be used for the new file.
  INPUT_EXTENSION=$(echo $(basename "${INPUT}" | cut -f 2 -d '.' | sed -e '/^\s*$/d' -e 's/\(.*\)/\U\1/'))

  SUBJECT=$(exiftool "${INPUT}" | grep "Subject")
  SUBJECT_SINGLEISO=$(exiftool "${INPUT}" | grep "Subject" | grep "Single ISO")
  SUBJECT_DUALISO=$(exiftool "${INPUT}" | grep "Subject" | grep "Dual ISO")

  # This is just for compatibility.
  SUBJECT_DUALISO_OLD=$(exiftool "${INPUT}" | grep "Subject" | grep "Dual-ISO")

  BASELINES=$(exiftool "${INPUT}" | grep "Baseline Exposure")

  C5DMK3_CHECK=$(exiftool "${INPUT}" |grep -i "5D Mark III" |wc -l)
  CROPHEIGHT_CHECK_VALUE=$(echo -n $(exiftool "${INPUT}" |grep -i "Cropped Image Height" | sed 's/[^0-9]*//g'))

  ISO_VALUE=$(echo -n $(exiftool "${INPUT}" | grep "Recommended Exposure Index" | grep -v "Sensitivity Type" | sed 's/[^0-9]*//g'))

################################################################

  # FIRST CHECK FOR INDIVIDUAL FILE

  ################################
  # CR2 FILES
  #
  # Input file is CR2 or cr2

  if [[ "${INPUT_EXTENSION}" == "CR2" ]]
  then

    # Dual ISO - unprocessed CR2 (NOTE: THIS CHECK IS SLOW)
    # Test an input file for Dual ISO.
    if [[ $(cr2hdr --dry-run "${INPUT}" | grep "Interlaced ISO detected" | wc -l) -eq 1 ]]
    then
      echo "${INPUT_BASENAME}: Dual ISO CR2 image. Skipping."
      IS_SINGLE_CR2=false
    else
      IS_SINGLE_CR2=true
    fi

    # Single ISO - CR2
    if [[ "${IS_SINGLE_CR2}" == true ]]
    then

      # Subject Tag
      if [[ $(echo "${SUBJECT}" | sed '/^\s*$/d' | wc -l) -eq 0 ]]
      then
        echo "${INPUT_BASENAME}: Add a new Subject tag."
        SUBJECT_TAG="Single ISO CR2"
        PROCESS_SUBJECT=true
      else
        echo "${INPUT_BASENAME} is a Single ISO image and has a Subject tag already."
        PROCESS_SUBJECT=false
      fi

      # Baseline Tags
      if [[ $(echo "${BASELINES}" | sed '/^\s*$/d' | wc -l) -eq 0 ]]
      then
        echo "${INPUT_BASENAME}: Add new Baseline tags."
        PROCESS_BASELINE=true
      else
        echo "${INPUT_BASENAME}: Baseline tags exist. Skipping."
        PROCESS_BASELINE=false
      fi

      # Image size
      if [[ "${CROPHEIGHT_CHECK_VALUE}" -ne "${C5DMK3_HEIGHT}" ]]
      then
        echo "${INPUT_BASENAME}: New resolution, ${C5DMK3_WIDTH} x ${C5DMK3_HEIGHT}."
        PROCESS_SIZE=true
      else
        echo "${INPUT_BASENAME}: Has correct resolution already."
        PROCESS_SIZE=false
      fi

    fi

  ################################
  # DNG FILES
  #
  # Input file is DNG or dng

  elif [[ "${INPUT_EXTENSION}" == "DNG" ]]
  then

    ###########
    # DNG with missing Subject Tag

    if [[ $(echo "${SUBJECT}" | sed '/^\s*$/d' | wc -l) -eq 0 ]]
    then

      echo "${INPUT_BASENAME}: Add a new Subject tag."
      SUBJECT_TAG="Single ISO CR2"
      PROCESS_SUBJECT=true

      # We don't update size tags. See reason below.
      # Baseline tags have already been written by Adobe converter.
      PROCESS_SIZE=false
      PROCESS_BASELINE=false

    ###########
    # DNG with updated Subject Tag

    elif [[ $(echo "${SUBJECT_SINGLEISO}" | sed '/^\s*$/d' | wc -l) -ne 0 ]]
    then
      echo "${INPUT_BASENAME}: Subject tag exists. Skipping."
      PROCESS_SUBJECT=false

      # We don't update size tags. See reason below.
      # Baseline tags have already been written by Adobe converter.
      PROCESS_SIZE=false
      PROCESS_BASELINE=false

    ###########
    # New Dual ISO - DNG

    elif [[ $(echo "${SUBJECT_DUALISO}" | sed '/^\s*$/d' | wc -l) -ne 0 ]]
    then

      echo "${INPUT_BASENAME}: Dual ISO image with proper tags. Skipping."

      # Tags have already be written by updated cr2hdr.
      PROCESS_SUBJECT=false
      PROCESS_SIZE=false
      PROCESS_BASELINE=false

    ###########
    # Old Dual ISO - DNG

    elif [[ $(echo "${SUBJECT_DUALISO_OLD}" | sed '/^\s*$/d' | wc -l) -ne 0 ]]
    then

      echo "${INPUT_BASENAME}: old Dual ISO image. Update Subject & Baseline tags."
      exiftool -xmp:subject= "${INPUT}" -overwrite_original #Clear old tag

      PROCESS_SUBJECT=true
      SUBJECT_TAG="Dual ISO DNG"

      PROCESS_SIZE=false

      # Old dual ISOs don't have this one.
      PROCESS_BASELINE=true

    fi
  fi

################################################################

  # Suffix for the new file name

  # U = Uncropped     (PROCESS_SIZE)
  # S = Subject Tag   (PROCESS_SUBJECT)
  # B = Baseline Tags (PROCESS_BASELINE)

  # false, false, false
  if \
    [[ "${PROCESS_SUBJECT}"  == false ]] && \
    [[ "${PROCESS_BASELINE}" == false ]] && \
    [[ "${PROCESS_SIZE}"     == false ]]
  then
      SUFFIX=

  # true, true, true
  elif \
    [[ "${PROCESS_SUBJECT}"  == true ]] && \
    [[ "${PROCESS_BASELINE}" == true ]] && \
    [[ "${PROCESS_SIZE}"     == true ]]
  then
      SUFFIX=_USB

  # true, true, false
  elif \
    [[ "${PROCESS_SUBJECT}"  == true  ]] && \
    [[ "${PROCESS_BASELINE}" == true  ]] && \
    [[ "${PROCESS_SIZE}"     == false ]]
  then
      SUFFIX=_SB

  # false, true, true
  elif \
    [[ "${PROCESS_SUBJECT}"  == false ]] && \
    [[ "${PROCESS_BASELINE}" == true  ]] && \
    [[ "${PROCESS_SIZE}"     == true  ]]
  then
      SUFFIX=_UB

  # true, false, true
  elif \
    [[ "${PROCESS_SUBJECT}"  == true  ]] && \
    [[ "${PROCESS_BASELINE}" == false ]] && \
    [[ "${PROCESS_SIZE}"     == true  ]]
  then
      SUFFIX=_US

  # false, true, false
  elif \
    [[ "${PROCESS_SUBJECT}"  == false ]] && \
    [[ "${PROCESS_BASELINE}" == true  ]] && \
    [[ "${PROCESS_SIZE}"     == false ]]
  then
      SUFFIX=_B

  # true, false, false
  elif \
    [[ "${PROCESS_SUBJECT}"  == true  ]] && \
    [[ "${PROCESS_BASELINE}" == false ]] && \
    [[ "${PROCESS_SIZE}"     == false ]]
  then
      SUFFIX=_S

  # false, false, true
  elif \
    [[ "${PROCESS_SUBJECT}"  == false ]] && \
    [[ "${PROCESS_BASELINE}" == false ]] && \
    [[ "${PROCESS_SIZE}"     == true  ]]
  then
      SUFFIX=_U

  fi

################################################################

  # RESOLUTION TAGS MANIPULATION - non-Dual ISO CR2 only

  # 1) Check if Size process variable is true
  # 2) If question "Do we have a 5D Mark string in the file?" does not
  #    return 0, E.G. the camera model is 5D Mark 3.

  if \
    [[ "${PROCESS_SIZE}" == true ]] && \
    [[ "${C5DMK3_CHECK}" -ne 0 ]]
  then

    # According to file analysis done with CR2 and DNG files,
    # Cropped & Exif Width/Height tags should be written into CR2 files.
    # CR2 files require only Cropped Image Height/Width values,
    # but if we convert an uncropped CR2 file into DNG, we get wrong picture size.
    # To correct this for DNG files, Exif Height/Witdh values are required, too.

    # WHY WE DON'T CHANGE EXIF TAGS FOR DNG FILES HERE?
    # We can't uncrop DNG file procuded by Adobe algorithms (Adobe DNG Converter or raw2dng).
    # This is because Adobe's method writes a tag name "Default Crop Size" which can't be
    # changed afterwards without rendering the image unusable in Adobe Camera Raw software.
    #
    # My hypothesis about the issue is as follows:
    # Camera Raw may do some comparison check between dimensions defined in "Default Crop Size"
    # and some of the exif-unwritable Width/Height values. If there's a mismatch, the file can't
    # be opened in Adobe Camera Raw software. An image that can't be opened in ACR, is still
    # usable in some other RAW processing software (because their check for EXIF value tags differ).
    #
    # Every time I edited "Default Crop Size" value in DNG file, ACR gave me an error about
    # unsupported or corrupted file.

    exiftool \
      -CroppedImageWidth="${C5DMK3_WIDTH}" \
      -CroppedImageHeight="${C5DMK3_HEIGHT}" \
      -ExifImageWidth="${C5DMK3_WIDTH}" \
      -ExifImageHeight="${C5DMK3_HEIGHT}" \
      "${INPUT}" \
      -overwrite_original

    echo -e "${INPUT_BASENAME}: Image dimensions updated to ${C5DMK3_WIDTH} x ${C5DMK3_HEIGHT}.\n"

    # Other useful Height/Width tags are as follows:

    # -OriginalImageWidth
    # -OriginalImageHeight

    # -RelatedImageWidth
    # -RelatedImageHeight

  fi

################################################################

  # BASELINE TAGS ADDITION - non-Dual ISO CR2 only

  # 1) We can request that PROCESS variable returns true though it's set to
  #    false in Dual ISO CR2 images too. These CR2 images have Baseline values
  #    already added into EXIF metadata since 01/07/2017 (cr2hdr code patched).

  # 2) We check for Canon 5D Mark 3 here

  # NOTE: We don't care about the image resolution here.

  if \
    [[ "${PROCESS_BASELINE}" == true ]] && \
    [[ "${C5DMK3_CHECK}" -ne 0 ]]
  then

    # The following tags (with their respective values) are being used in DNG files
    # converted from CR2 files of Canon 5D Mark 3. Because CR2 files are mostly
    # equal to DNG files but these tags don't exist inside CR2 files, we can add them
    # as shown in the following section.

    # ######################################################
    #
    # Camera Model: Canon EOS 5D Mark III

    #   ISO Value       Baseline Exposure Value
    #
    #   100             0.25
    #   125             0.25
    #   200             0.25
    #   250             0.25
    #   400             0.25
    #   500             0.25
    #   800             0.25
    #   1000            0.25
    #   1600            0.25
    #   2000            0.25
    #   3200            0.25
    #   4000            0.25
    #   6400            0.25
    #   8000            0.25
    #   12800           0.25
    #   16000           0.25
    #   25600           0.25
    #
    #   50             -0.75
    #   160             0.02
    #   320             0.01
    #   640             0.01
    #   1250            0.01
    #   2500            0.01
    #   5000            0.01
    #   10000           0.01
    #   20000           0.01
    #   51200           0.36
    #   102400          0.36
    #
    #   ######################################################
    #
    #   Same values for all ISOs:
    #
    #   Baseline Noise          0.8
    #   Baseline Sharpness      1.2
    #   Bayer Green Split       100
    #
    #   ######################################################
    #
    #   Camera Profiles in Adobe Camera RAW - Baseline Exposure Offsets:
    #
    #   All Canon EOS 5D Mark 3 profiles (Standard, Neutral, Landscape etc.): -0.25
    #   Adobe Standard Profile: 0.00
    #
    #   ######################################################

    #   We Do ISO check with Exposure Index value (It returns the same
    #   value than used ISO, and works with ISO 102400, too).

    if [[ "${ISO_VALUE}" -eq 50 ]]
    then
      BL_EXP=-0.75

    elif [[ "${ISO_VALUE}" -eq 160 ]]
    then
      BL_EXP=0.02

    elif \
      [[ "$ISO_VALUE}" -eq 51200 ]] || \
      [[ "$ISO_VALUE}" -eq 102400 ]]
    then
      BL_EXP=0.36

    elif \
      [[ "${ISO_VALUE}" -eq 320 ]] || \
      [[ "${ISO_VALUE}" -eq 640 ]] || \
      [[ "${ISO_VALUE}" -eq 1250 ]] || \
      [[ "${ISO_VALUE}" -eq 2500 ]] || \
      [[ "${ISO_VALUE}" -eq 5000 ]] || \
      [[ "${ISO_VALUE}" -eq 10000 ]] || \
      [[ "${ISO_VALUE}" -eq 20000 ]]
    then
      BL_EXP=0.01

    else
      BL_EXP=0.25
    fi

    exiftool \
      -BaselineExposure="${BL_EXP}" \
      -BaselineNoise=0.8 \
      -BaselineSharpness=1.2 \
      -BayerGreenSplit=100 \
      "${INPUT}" \
      -overwrite_original

    echo -e "${INPUT_BASENAME}: Baseline tags added.\n"

  fi

################################################################

  # SUBJECT TAG ADDITION

  if \
    [[ "${PROCESS_SUBJECT}" == true ]] && \
    [[ "${C5DMK3_CHECK}" -ne 0 ]]
  then
    exiftool -xmp:subject="${SUBJECT_TAG}" "${INPUT}" -overwrite_original
    echo -e "${INPUT_BASENAME}: New Subject tag added: $SUBJECT_TAG\n"
  fi

################################################################

  # FILE SUFFIX ADDITION

  exiftool "-FileModifyDate<EXIF:DateTimeOriginal" "${INPUT}"

  NEWFILE="${INPUT_DIR}"/"${INPUT_BASENAME}${SUFFIX}"."${INPUT_EXTENSION}"

  mv "${INPUT}" "${NEWFILE}"

  exiftool '-FileName<DateTimeOriginal' -d '%Y%m%d-%f%%-c.%%e' "${NEWFILE}"
  #touch --date=@"${INPUT_MTIME}" "${NEWFILE}"

  if [[ "${2}" != "" ]]; then
    echo "Moving to the next file."
  fi

################################################################

  # PROGRESSBAR CODE - BEGIN

  let inc++

  # Percentage needs to be calculated like this due to bash rounding limitations.
  PERCENT_VALUE=$(((${mltp}*${tics})/(200*${numargs}/${inc} % 2 + ${mltp}*${numargs}/${inc})))
  # Output: 20, 40, 59, 80, 100 etc.

  qdbus $dbusRef Set "" "value" "${PERCENT_VALUE}";
  qdbus $dbusRef setLabelText "${LABELTEXT} (${inc}/${numargs})";

  # PROGRESSBAR CODE - END

  # Move to the next file.
  shift
done

##############################################

# Close processing window if cancelled event has been triggered.

# PROGRESSBAR CODE - BEGIN

# If the process was cancelled, remove tmp file and exit the script.
if [[ ! $(qdbus $dbusRef wasCancelled) == "false" ]]; then
  exit 0
fi

#Close processing window if not cancelled and processing finished.

qdbus $dbusRef close

# PROGRESSBAR CODE - END

exit 0
