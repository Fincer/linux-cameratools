#!/bin/env bash

#    Statistics of camera RAW images with GNU Plot & Exiftool
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

# TODO list:

# TODO Add message, either of these:
#   If not a geotagged image file:
#   A You haven't geotagged selected photos. Are you sure you want to continue?
#   B Following photos don't have altitude value: XX XX XX Are you sure you want to continue?

# TODO IF INPUT IS A CSV FILE, DO NOT SUGGEST 'EXPORT ONLY' AS AN OPTION

# TODO if user chooses alternative 'Export CSV' only, do not crash if errtags or errnames encountered

#
# TODO Be more specific in which case errtags may crash the operation. For instance, if user has chosen only Temperature and ISO to be plotted on GNU Plot, do not crash in case where Focal Length is missing. In other words: be more specific in which conditions match the crash requirement, do not crash the process for nothing.

# TODO The script has only been tested on Canon 5D Mark 3 CR2 files. How does the script work with other Canon camera models? And what about Sony, Nikon?
#

# TODO Re-write, parse and simplify some scripts logics!

###############################################

# Supported & tested camera raw pictures:
# Canon EOS 5D Mark 3

# TOOL REQUIREMENTS
#   perl-exiftool
#   kdialog (Qt5)
#   qt5-tools (qdbus)
#   coreutils (md5sum, echo etc..)
#   netpbm (pgmhist)
#   dcraw
#   gawk
#   gnuplot (+ Qt interface)
#
#
# OTHER REQUIREMENTS
#
# Recommended: Qt5 Dolphin file manager (dolphin)
#
# This script is meant to be run as a Dolphin File Manager script (Qt5). It gets file arguments straight from Dolphin
# You can run the script in bash (or execute Dolphin via bash) to get detailed script output (CLI messages, debug messages etc.)
#

#######################################################################

CSV_FILECOUNT=$(printf '%s\n' "${@}" | rev | cut -f 1 -d '.' | rev | grep -i "csv" | wc -l)
RAW_FILECOUNT=$(printf '%s\n' "${@}" | rev | cut -f 1 -d '.' | rev | grep -i -E "cr2|nef|dng" | wc -l)

# Count of all columns must be found in CSV file.
# This number must match with the number found in kdialog processing dialog below.
COLUMNCOUNT=24

#######################################################################

# The first file check

if [[ "${@}" == "" ]]
then
  kdialog --error "Not any files selected!";
  exit 1

elif \
  [[ ! "${CSV_FILECOUNT}" -eq 0 ]] && \
  [[ ! "${RAW_FILECOUNT}" -eq 0 ]]
then
  kdialog --error "Select only RAW files or a single CSV file!";
  exit 1

elif [[ "${CSV_FILECOUNT}" -gt 1 ]]
then
  kdialog --error "Select only one CSV file!";
  exit 1

elif [[ "${RAW_FILECOUNT}" -eq 1 ]]
then
  kdialog --error "Please select at least 2 valid RAW files or a CSV file!";
  exit 1

elif \
  [[ "${RAW_FILECOUNT}" -eq 0 ]] && \
  [[ "${CSV_FILECOUNT}" -eq 0 ]]
then
  kdialog --error "Please select valid RAW files or a CSV file!";
  exit 1
fi

#######################################################################

# KDialog check list formatted selection window

if \
  [[ $RAW_FILECOUNT == 0 ]] && \
  [[ $CSV_FILECOUNT == 1 ]]
then

  SELECTION=$(kdialog --checklist "Select statistics to display:" \
    1 "Apertures, Exposures & ISOs" off \
    2 "Focal Lengths & Lenses" off \
    3 "Temperatures & ISOs" on \
    4 "Shooting & Focus Modes" off \
  );

  # 1 Apertures, Exposures & ISOs
  # 2 Focal Lengths & Lenses
  # 3 Temperatures & ISOs
  # 4 Shooting & Focus Modes

  if [[ "$?" = 0 ]]; then
    if [[ $(expr length "$SELECTION") -ne 0 ]]
    then
      for result in $SELECTION
      do
        [[ "${result}" = '"1"' ]] && SEL1=true
        [[ "${result}" = '"2"' ]] && SEL2=true
        [[ "${result}" = '"3"' ]] && SEL3=true
        [[ "${result}" = '"4"' ]] && SEL4=true
      done

    else
      kdialog --sorry "Aborted";
    fi

  elif [[ "$?" -eq 1 ]]
  then
    exit 0
  else
    kdialog --error "Unexpected Error";
  fi
  SEL5=false
fi

if \
  [[ $RAW_FILECOUNT -ne 0 ]] && \
  [[ $CSV_FILECOUNT -eq 0 ]]
then

  SELECTION=$(kdialog --checklist "Select statistics to display:" \
    1 "Apertures, Exposures & ISOs" off \
    2 "Focal Lengths & Lenses" off \
    3 "Temperatures & ISOs" on \
    4 "Shooting & Focus Modes" off \
    5 "Export Only (CSV)" off \
  );

  # 1 Apertures, Exposures & ISOs
  # 2 Focal Lengths & Lenses
  # 3 Temperatures & ISOs
  # 4 Shooting & Focus Modes
  # 5 Export Only (CSV)

  if [[ "$?" = 0 ]]; then
    if [ $(expr length "$SELECTION") -ne 0 ]
    then
      for result in $SELECTION
      do
        [[ "${result}" = '"1"' ]] && SEL1=true
        [[ "${result}" = '"2"' ]] && SEL2=true
        [[ "${result}" = '"3"' ]] && SEL3=true
        [[ "${result}" = '"4"' ]] && SEL4=true

        # If checked, we force all other values to be false
        if [[ "${result}" = '"5"' ]]
        then
          SEL5=true
          SEL4=false
          SEL3=false
          SEL2=false
          SEL1=false
        fi
      done
    else
      kdialog --sorry "Aborted";
    fi

  elif [[ "$?" -eq 1 ]]
  then
      exit 0
  else
    kdialog --error "Unexpected Error";
  fi
fi

# SEL1 = "Apertures, Exposures & ISOs"  true/false
# SEL2 = "Focal Lengths & Lenses"       true/false
# SEL3 = "Temperatures & ISOs"          true/false
# SEL4 = "Shooting & Focus Modes"       true/false
# SEL5 = "Export Only (CSV)"            true/false

#######################################################################

# We get the directory just from the first filename.
INPUT_DIR=$(dirname "${1}")
DIR_BASENAME=$(echo -n "${INPUT_DIR}" | rev | cut -d'/' -f 1 | rev)

# First & Last file names (without suffixes).
for last; do true; done

# Name of the first file passed into the script.
FIRST=$(basename "${1}" | cut -f 1 -d '.')
# Name of the last file passed into the script.
LAST=$(basename "${last}" | cut -f 1 -d '.')

# File name is based on the folder where files exist
FILENAME=$(echo "${DIR_BASENAME}-${FIRST}-${LAST}_metadata")
FILE_EXT=.csv

#######################################################################
# 2ND FILE CHECK

# Check if we are dealing with a CSV file or bunch of RAW files.

if [[ "${CSV_FILECOUNT}" -eq 1 ]]; then

  # Without a suffix. We use valid existing CSV file name here.
  FILENAME=$(basename "${1}" | sed 's/\.\w*$//')
  CSVFOLDER="${INPUT_DIR}" 

elif [[ "${RAW_FILECOUNT}" -ne 0 ]]; then
  echo "Multiple RAW files."
fi

RAWDATA_TMP="${CSVFOLDER}/${FILENAME}${FILE_EXT}"

#######################################################################

# 1) Check CSV file validity against the script output.
# 2) Get value for 'INPUT_FILES_MD5SUM' variable.

# NOTE: We don't check MD5Sums, if we use CSV file as an input.
# Though this file can exist in the same folder with the pictures,
# we want to keep CSV files as portable as possible in general. 
# Thus, we don't do the following check: CSV file list MD5Sums
# vs actual corresponding files in the folder (if only CSV is selected as input).
# This can arise other problems such as images with equivalent names listed in
# CSV file but they are actually different files.
# This causes mismatch between CSV file content and folder content. So, no go.

# 1) Check validity of the selected CSV file for analysis purposes. Not RAW files selected.

# Referring to existing CSV file here. User input may or may not be a CSV file, so we don't check it.
if [[ -e "${RAWDATA_TMP}" ]]
then

  echo "This is a valid CSV file. Checking columns."

  # This *must* return only one value (equal to COLUMNCOUNT).
  # If many values are returned CSV file can't be used because,
  # therefore, there are mismatch between column numbers in rows.
  FILE_COLUMNCOUNT=$(echo -n $(awk -F ',' '{print NF}' "${RAWDATA_TMP}" | sort -nu))
  
  FILE_HASMD5COLUMN=$(awk -F ',' '{print $2}' "${RAWDATA_TMP}" | head -n 1)
  FILE_MD5_CHARNUM=$(echo -n $(awk -F ',' ' FNR > 1 {print length($2)}' "${RAWDATA_TMP}" | sort -nu)) #This *must* return only one value. Value 32.

  # If the input csv file has valid count of columns and the second column includes md5sums.
  if \
    [[ "${FILE_COLUMNCOUNT}" -eq "${COLUMNCOUNT}" ]] && \
    [[ "${FILE_HASMD5COLUMN}" == "File MD5Sum" ]] && \
    [[ "${FILE_MD5_CHARNUM}" -eq 32 ]]
  then
    COLUMNS_OK=true
    echo "Columns OK, continuing."

  elif [[ "${RAW_FILECOUNT}" -eq 0 ]]
  then
    echo -e "Charnum is: ${FILE_MD5_CHARNUM}"
    echo "Error in columns."
    kdialog --error "Error in CSV file columns!";
    exit 0

  else
    echo "Error in matching file columns. RAW files as input."
    
    # This is a case where we have detected a pattern matcing CSV file but it has invalid columns.
    COLUMNS_OK=false
  fi
fi

# 2) Instead of single CSV file, if multiple RAW files have been selected, then
if [[ "${RAW_FILECOUNT}" -ne 0 ]]
then

  echo "Getting MD5Sums for RAW files..."
        
  # Get md5sums for the files and print output.
  # Syntax: IMG_8217,IMG_8408,IMG_8544 ...
  # (replace these file names just with md5sums and you get the idea)
  INPUT_FILES_MD5SUM=$(
    echo -n $(printf '%s\n' $(md5sum "${@}") | \
      sed '$!N;s/\n/ /' | \
      awk -F ' ' '{print $2,$1}' | \
      sed -e 's/^.*\///' | \
      sort -n | \
      awk -F ' ' '{print $2}' | \
      tr '\n' ',' | \
      sed 's/,*\r*$//'
    )
  )

  echo "Comparing MD5Sums..."

  MAINCSV=$(find "${CSVFOLDER}" -maxdepth 1 -iname "${FILENAME}*${FILE_EXT}")
  MAINCSV_COUNT=$(find "${CSVFOLDER}" -maxdepth 1 -iname "${FILENAME}*${FILE_EXT}" | wc -l)

  OTHER_CSV=$(find "${CSVFOLDER}" -maxdepth 1 -iname "*${FILE_EXT}")
  OTHER_CSV_COUNT=$(find "${CSVFOLDER}" -maxdepth 1 -iname "*${FILE_EXT}" | wc -l)

  # Main CSV file
  if [[ "${COLUMNS_OK}" == true ]]; then

    COMPAREFILE_MD5SUM=$(
      echo -n $(
        awk -F ',' 'FNR> 1 {print $1,$2}' "${RAWDATA_TMP}" | \
        sort -n | \
        awk -F ' ' '{print $2}' | \
        tr '\n' ',' | \
        sed 's/,*\r*$//'
      )
    )

    # If md5sums match OK, then
    if [[ "${INPUT_FILES_MD5SUM}" == "${COMPAREFILE_MD5SUM}" ]]
    then
      echo -e "MD5Sums match OK."
      USEMAINCSV=true
    else
      echo -e "MD5Sums match not OK."
      USEMAINCSV=false
    fi
  fi

  # Other CSV files, including variant of the CSV "file template".
  if \
    [[ ! -e "${RAWDATA_TMP}" ]] || \
    [[ "${OTHER_CSV_COUNT}" -ne 0 ]] || \
    [[ "${USEMAINCSV}" == false ]]
  then

    # Check for CSV variants (which match the filename syntax).
    if [[ "${MAINCSV_COUNT}" -gt 0 ]]
    then
  
      for m in ${MAINCSV}
      do
          
        COMPAREFILE_MD5SUM=$(
          echo -n $(
            awk -F ',' 'FNR> 1 {print $1,$2}' "${m}" | \
            sort -n | \
            awk -F ' ' '{print $2}' | \
            tr '\n' ',' | \
            sed 's/,*\r*$//'
          )
        )
  
        if [[ "${INPUT_FILES_MD5SUM}" == "${COMPAREFILE_MD5SUM}" ]]
        then
          RAWDATA_TMP="${m}"

          # We get the existing file name template and remove extension.
          FILENAME=$(basename "${m}" | cut -f 1 -d '.')
          USEMAINCSV=true
          break
        else
          USEMAINCSV=false
        fi
      done
    fi
  
    # Check for other CSVs.
    if \
      [[ "${MAINCSV_COUNT}" -eq 0 ]] || \
      [[ "${OTHER_CSV_COUNT}" -ne 0 ]] && \
      [[ "${USEMAINCSV}" == false ]]
    then
  
      for f in ${OTHER_CSV}
      do
        COMPAREFILE_MD5SUM=$(
          echo -n $(
            awk -F ',' 'FNR> 1 {print $1,$2}' "${f}" | \
            sort -n | \
            awk -F ' ' '{print $2}' | \
            tr '\n' ',' | \
            sed 's/,*\r*$//'
          )
        )
  
        if [[ "${INPUT_FILES_MD5SUM}" == "${COMPAREFILE_MD5SUM}" ]]
        then
          RAWDATA_TMP="${f}"

          # We get the existing file name template and remove extension.
          FILENAME=$(basename "${f}" | cut -f 1 -d '.')
          USEOTHERCSV=true
          break
        else
          USEOTHERCSV=false
        fi
      done
    fi
  fi
fi

if \
  [[ ${USEMAINCSV} == false ]] && \
  [[ ${USEOTHERCSV} == false ]]
then

  x=1
  while [[ -e "${CSVFOLDER}/${FILENAME}-${x}${FILE_EXT}" ]]
  do
    let x++
  done
  FILENAME="${FILENAME}-${x}"
fi

echo -e "MD5Sums checked.\n"


if \
  [[ $USEMAINCSV == true ]] || \
  [[ $USEOTHERCSV == true ]]
then
  echo -e "Found an existing CSV file with MD5Sums.\n"

elif \
  [[ $USEMAINCSV == true ]] && \
  [[ $USEOTHERCSV == false ]]
then
  echo -e "Using existing CSV with correct file template.\n"

elif \
  [[ $USEMAINCSV == true ]] && \
  [[ $USEOTHERCSV == false ]]
then
  echo -e "Using a custom named CSV file.\n"

elif \
  [[ $USEMAINCSV == false ]] || \
  [[ $USEOTHERCSV == false ]]
then
  echo -e "Creating a new CSV file.\n"
fi

#######################################################################

# We need to redefine bash variables to overwrite the old values!
FILENAME2="${FILENAME}-temp"
FILENAME3="${FILENAME}-iso"

RAWDATA_TMP="${CSVFOLDER}/${FILENAME}${FILE_EXT}"
RAWDATA_TMP2="/tmp/${FILENAME2}${FILE_EXT}"
RAWDATA_TMP3="/tmp/${FILENAME3}${FILE_EXT}"

#################

#DEBUGGING
echo "We use file named $RAWDATA_TMP"

if [[ "${SEL3}" == true ]]
then
  echo "We use isofile named $RAWDATA_TMP2"
  echo "We use tempfile named $RAWDATA_TMP3"
fi


#######################################################################

# PROGRESSBAR CODE - BEGIN

LABELTEXT="Exporting statistics..."
numargs=$# # Number of all files
tics=100   # Percentage tics
inc=0      # Current file number
mltp=1000  # Percentage multiplier for bash

# If the file already exists, we don't want overwrite it.
# Instead, we skip these steps to speed up the process.
if [[ ! -e "${RAWDATA_TMP}" ]]
then
  dbusRef=$(kdialog --title "Metadata Extraction (${DIR_BASENAME}: images ${FIRST}-${LAST})" --progressbar "${LABELTEXT}" "${tics}")
  qdbus $dbusRef showCancelButton true

# PROGRESSBAR CODE - END

while \
  [[ $# -gt 0 ]] && \
  [[ $(qdbus $dbusRef wasCancelled) == "false" ]]
do

  i="${1}"

##############################################
# 1 COLUMN

  # ENABLE THIS IF STATEMENT ONLY IF FILE NAMES CONTAINING 'IMG_' ARE THE ONLY ONES ACCEPTED

  #if [[ ! $(echo $(basename "${1}" | cut -f 1 -d '.')) == *"IMG_"* ]]
  #then
  #  echo $(basename "${1}" | cut -f 1 -d '.')
  #  ERRFILE=1 #PRINT INVALID INPUT AS THE LAST COLUMN DUE TO DATE/TIME COLUMNS! SEE BELOW!
  #else
  echo $(basename "${i}" | cut -f 1 -d '.') #| sed -e 's/IMG_//g') #echo ${i##*/} | sed -e 's/.CR2//g' -e 's/.DNG//g')
  #  ERRFILE=0
  #fi

##############################################
# 2 COLUMN - md5sum

  # Write md5sum of a file for checking purposes!
  md5sum "${i}" | awk -F ' ' '{print $1}'

##############################################
# 3 COLUMN - temperature

  if [[ $(exiftool "${i}" |grep --max-count=1 "Camera Temperature" | sed -e 's/[^0-9]*//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Camera Temperature" | sed -e 's/[^0-9]*//g'
  else
    echo "errtag"
  fi

##############################################
# 4 COLUMN - sensitivity

  # ISO Speed setting (yeah, we get it from "Recommended Exposure Index" tag.

  if [[ $(exiftool "${i}" | grep -v "Sensitivity" | grep --max-count=1 "Recommended Exposure Index" | sed 's/[^0-9]*//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" | grep -v "Sensitivity" | grep --max-count=1 "Recommended Exposure Index" | sed 's/[^0-9]*//g'
  else
    echo "errtag"
  fi

##############################################
# 5 COLUMN - exposure time

  if [[ $(exiftool "${i}" |grep --max-count=1 "Exposure Time" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Exposure Time" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 6 COLUMN - target exposure time

  if [[ $(exiftool "${i}" |grep --max-count=1 "Target Exposure Time" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Target Exposure Time" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 7 COLUMN - exposure compensation

  if [[ $(exiftool "${i}" |grep --max-count=1 "Exposure Compensation" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Exposure Compensation" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 8 COLUMN - aperture

  if [[ $(exiftool "${i}" |grep --max-count=1 "Aperture Value" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Aperture Value" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 9 COLUMN - target aperture

  if [[ $(exiftool "${i}" |grep --max-count=1 "Target Aperture" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Target Aperture" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 10 COLUMN

# Average histogram value for image (brightness etc.)
# For documentation, see http://netpbm.sourceforge.net/doc/pgmhist.html
# we need to convert the image into grayscale with dcraw -d option
# dcraw "manual" is found here: http://www.inweb.ch/foto/dcrawhelp.txt

  if [[ $(dcraw -d -4 -j -c "${i}" | pgmhist -median | wc -l) -eq 1 ]]
  then
    dcraw -d -4 -j -c "${i}" | pgmhist -median | sed 's/[^0-9]*//g'
  else
    echo "errtag"
  fi

############################################## 
# 11 COLUMN - focal length

  if [[ $(exiftool "${i}" |grep --max-count=1 "Focal Length" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' -e 's/ //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Focal Length" | sed -e 's/[A-Za-z]*//g' -e 's/.*: //g' -e 's/ //g'
  else
    echo "errtag"
  fi

##############################################
# 12 COLUMN - hyperfocal distance

  if [[ $(exiftool "${i}" |grep --max-count=1 "Hyperfocal Distance" | sed -e 's/.*: //g' -e 's/ m//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Hyperfocal Distance" | sed -e 's/.*: //g' -e 's/ m//g'
  else
    echo "errtag"
  fi

##############################################
# 13 COLUMN - upper focus distance

  if [[ $(exiftool "${i}" |grep --max-count=1 "Focus Distance Upper" | sed -e 's/.*: //g' -e 's/ m//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Focus Distance Upper" | sed -e 's/.*: //g' -e 's/ m//g'
  else
    echo "errtag"
  fi

##############################################
# 14 COLUMN - lower focus distance

  if [[ $(exiftool "${i}" |grep --max-count=1 "Focus Distance Lower" | sed -e 's/.*: //g' -e 's/ m//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Focus Distance Lower" | sed -e 's/.*: //g' -e 's/ m//g'
  else
    echo "errtag"
  fi

##############################################
# 15 COLUMN - depth of field

  if [[ $(exiftool "${i}" |grep --max-count=1 "Depth Of Field" | sed -e 's/.*: //g' -e 's/ m//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Depth Of Field" | sed -e 's/.*: //g' -e 's/ m//g'
  else
    echo "errtag"
  fi
        
##############################################
# 16 COLUMN - camera model

  if [[ $(exiftool "${i}" |grep --max-count=1 "Camera Model Name" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Camera Model Name" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 17 COLUMN - lens type

  if [[ $(exiftool "${i}" |grep --max-count=1 "Lens Type" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Lens Type" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 18 COLUMN - focus mode

  if [[ $(exiftool "${i}" |grep --max-count=1 "Focus Mode" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Focus Mode" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 19 COLUMN - shooting mode

  if [[ $(exiftool "${i}" |grep --max-count=1 "Shooting Mode" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Shooting Mode" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 20 COLUMN - live view shooting

  if [[ $(exiftool "${i}" |grep --max-count=1 "Live View Shooting" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Live View Shooting" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 21 COLUMN - camera orientation

  if [[ $(exiftool "${i}" |grep --max-count=1 "Camera Orientation" | sed 's/.*: //g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Camera Orientation" | sed 's/.*: //g'
  else
    echo "errtag"
  fi

##############################################
# 21 COLUMN - subject

  if [[ $(exiftool "${i}" |grep --max-count=1 "Subject" | sed -e 's/.*: //g' | wc -l) -eq 0 ]]
  then

    # If Subject tag is empty, get input file filetype (CR2 or cr2 // DNG or dng)
    if [[ $(echo $(basename "${i}" | cut -f 2 -d '.' | sed -e '/^\s*$/d' -e 's/\(.*\)/\U\1/')) == "CR2" ]]
    then
      echo "Single ISO CR2"

    elif [[ $(echo $(basename "${i}" | cut -f 2 -d '.' | sed -e '/^\s*$/d' -e 's/\(.*\)/\U\1/')) == "DNG" ]]
    then
      echo "Single ISO DNG"
    fi

  # If we have a real Subject tag, extract info from it
  else
    exiftool "${i}" |grep --max-count=1 "Subject" | sed -e 's/.*: //g'
  fi

##############################################
# 23 COLUMN - datetime original

  if [[ $(exiftool "${i}" |grep --max-count=1 "Date/Time Original" | sed -e 's/.*: //g' | cut -d' ' -f1 | awk -F ":" '{print $3, $2, $1}' | sed -e 's/ /\//g' | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Date/Time Original" | sed -e 's/.*: //g' | cut -d' ' -f1 | awk -F ":" '{print $3, $2, $1}' | sed -e 's/ /\//g'
  else
    echo "errtag"
  fi

##############################################
# 24 COLUMN - datetime original
  if [[ $(exiftool "${i}" |grep --max-count=1 "Date/Time Original" | sed -e 's/.*: //g' | cut -d' ' -f2 | wc -l) -eq 1 ]]
  then
    exiftool "${i}" |grep --max-count=1 "Date/Time Original" | sed -e 's/.*: //g' | cut -d' ' -f2
  else
    echo "errtag"
  fi

##############################################
# ENABLE THIS FOR CHECKING FILE NAMES. IF ENABLED, ALL FILES MUST CONTAIN 'IMG_' STRING OR OTHERWISE, THEY ARE EXCLUDED FROM THE STATISTICS!

# Write this line/column only, if an invalid file name has been detected
# if [[ "$ERRFILE" -eq 1 ]]; then
#   echo "errname"
# fi

##############################################

  # This is written just as a dummy separator for each processed files for further line separation done below.
  echo "newline" 

##############################################

  # PROGRESSBAR CODE - BEGIN
  
  # This section is increasing values seen in the kdialog processing window.
  
  let inc++
  
  #Percentage needs to be calculated like this due to bash rounding limitations...
  PERCENT_VALUE=$(((${mltp}*${tics})/(200*${numargs}/${inc} % 2 + ${mltp}*${numargs}/${inc})))
  
  qdbus $dbusRef Set "" "value" "${PERCENT_VALUE}";
  qdbus $dbusRef setLabelText "${LABELTEXT} (${inc}/${numargs})";
  
  # PROGRESSBAR CODE - END
  
  shift

##############################################

  # Sort output:
  #   replace newlines with commas
  #   remove more commas
  #   replace 'newline' with a new line
  #   trim the first and the last commas of any line
  #   sort lines by Date & Time (23th & 24th column)
  #   write output

done | \
tr '\n' ',' | \
sed -e 's/,[^,]*$//' -e 's/newline/\n/g' | \
sed -e 's/^,//g' -e 's/\(.*\),/\1/' | \
sort -t ',' -n -k23 -k24 | \
sed 's/inf/∞/g' \
> "${RAWDATA_TMP}"

#| sed 's/newline/\n/g' | sort -u

##############################################

# Close processing window if cancelled event has been triggered.

# PROGRESSBAR CODE - BEGIN

# If the process was cancelled, remove tmp file and exit the script.
if [[ ! $(qdbus $dbusRef wasCancelled) == "false" ]]; then

  # We can delete the file because its existence has been checked before the processing
  # window has been opened. Thus we don't get here, if the file already exists.
  rm -f "${RAWDATA_TMP}"
  exit 0
fi

# PROGRESSBAR CODE - END

###########################################

#Add correct titles to the first row in RAWDATA_TMP file:
sed -i '1s/^/Image File,File MD5Sum,Camera Temperature,ISO,Shutter Speed,Target Exposure,Exposure Compensation,Aperture,Target Aperture,Histogram Median,Focal Length,Hyperfocal Distance,Upper Focus Distance,Lower Focus Distance,Depth Of Field,Camera Model,Lens Model,Focus Mode,Exposure Mode,Live View,Camera Orientation,ISO Type,Date,Time\n/' "${RAWDATA_TMP}"

#Close processing window if not cancelled and processing finished.
# PROGRESSBAR CODE - BEGIN

qdbus $dbusRef close

# PROGRESSBAR CODE - END

# SEL1 = "Apertures, Exposures & ISOs"  true/false
# SEL2 = "Focal Lengths & Lenses"       true/false
# SEL3 = "Temperatures & ISOs"          true/false
# SEL4 = "Shooting & Focus Modes"       true/false
# SEL5 = "Export Only (CSV)"            true/false

if [[ "${SEL5}" == true ]]
then
  kdialog --msgbox "EXIF data exported successfully";
  exit 0
fi

elif \
  [[ -e "${RAWDATA_TMP}" ]] && \
  [[ "${SEL5}" == true ]]
then
  kdialog --msgbox "EXIF data exported already.\n\nFile:\n\n${RAWDATA_TMP}";
  exit 0
fi

# KDIALOG PROCESSING WINDOW - END

##############################################

# Check RAWDATA_TMP for bad line outputs

# 1) BADFILES: Open written (or existing) CSV file
# 2) BADFILES: List all lines matching pattern "errname" or "errtag"
# 3) BADFILES: Write output as a single line, using comma mark to separate the written output (file names).
#              Remove the last extra comma.

BADFILES=$(cat "${RAWDATA_TMP}" | sed -ne '/errname/p' -ne '/errtag/p' | sed 's/,.*$//')
BADFILES_COUNT=$(cat "${RAWDATA_TMP}" | sed -ne '/errname/p' -ne '/errtag/p' | sed 's/,.*$//' | wc -l)
    
#Count lines found in the output of BADFILES. If not zero (e.g. bad strings found), then
if [[ "${BADFILES_COUNT}" -ne 0 ]]
then

  cat "${RAWDATA_TMP}" | sed -e '/errname/d' -e '/errtag/d' > "/tmp/${FILENAME}-errtags${FILE_EXT}"
  
  # We don't want to overwrite the original file.
  RAWDATA_TMP_ERR="/tmp/${FILENAME}-errtags${FILE_EXT}"

  # If not any valid output image files. Minimum count of lines is 2.
  if [[ $(cat "${RAWDATA_TMP_ERR}" | wc -l) == 1 ]]
  then

    kdialog --error "Could not process any input file:\n\n${BADFILES}\n\nThis can be due to missing EXIF data such as Temperature, ISO, Date or Time.\n\nPlease check CSV file (${FILENAME}${FILE_EXT}) contents to study the problem.\n\nExiting.";

    rm "${RAWDATA_TMP_ERR}"
    exit 1

  # If we have just a single file here. Minimum count of lines is 3.
  elif [[ $(cat "${RAWDATA_TMP_ERR}" | wc -l) -le 2 ]]
  then

    kdialog --error "Could not process a valid number of input files. Minimum count of valid files is 2.\n\nFiles that could not be processed:\n\n$BADFILES\n\nThis can be due to missing EXIF data such as Temperature, ISO, Date or Time.\n\nPlease check CSV file (${FILENAME}${FILE_EXT}) contents to study the problem.\n\nExiting."

    rm "${RAWDATA_TMP_ERR}"
    exit 1

  else

    mv "/tmp/${FILENAME}-errtags${FILE_EXT}" "${CSVFOLDER}/${FILENAME}-errtags${FILE_EXT}"
    RAWDATA_TMP="${CSVFOLDER}/${FILENAME}-errtags${FILE_EXT}"

    kdialog --msgbox "Could not process files:\n\n${BADFILES}\n\nThis can be due to missing EXIF data such as Temperature, ISO, Date or Time.\n\nPlease exclude these files or check CSV file (${FILENAME}${FILE_EXT}) contents to study the problem.\n\nNew CSV file written as (bad files excluded):\n${RAWDATA_TMP}";

  fi
fi

######################################################################################

FILELIST=$(
  echo -n $(
    awk -F ',' 'FNR> 1 {print $1}' "${RAWDATA_TMP}" | \
    sort -n | \
    tr ' ' '\n' | \
    sort -n | \
    tr '\n' ',' | \
    sed 's/,*\r*$//'
  )
)

#Total count of accepted pictures, used for further data representation in gnuplot.
# We reduce it by 1 due to file header (column titles are not counted):
ACCEPTED_TOTAL=$(echo -n $(($(cat "${RAWDATA_TMP}" | wc -l) - 1)))

######################################################################################

# GNUPLOT CODE - BEGIN

GNUPLOT_MAINWINDOW_TITLE=$(echo "${DIR_BASENAME} (${ACCEPTED_TOTAL} images, ${FILENAME})")

###########################################################
# GNUPlot time values

# PLOT 1

# Should we use time values in the first plot?
# If too many images, plot is basically rendered unreadable.
# Rotate x labels if there are too many items to be shown.

# Do not rotate x labels, if we have less than 10 images selected.
if [[ $ACCEPTED_TOTAL -lt 10 ]]
then

  X_ROTATELABELS=$(echo -n "")
  
  # Time values are only if max 6 images selected.
  if [[ $ACCEPTED_TOTAL -le 6 ]]
  then
    X2_TIMESTRINGS=$(echo -n "set x2tics offset 0,-0.5")
  else
    X2_TIMESTRINGS=$(echo -n "unset x2tics")
  fi
else
  X_ROTATELABELS=$(echo -n "set xtics rotate 90")
fi

############################################################

# Image count/unit scales for GNUPlot plots 2 & 3

if [[ "${ACCEPTED_TOTAL}" -le 10 ]]; then
  SCALE=1
elif [[ "${ACCEPTED_TOTAL}" -gt 10 ]] && [[ "${ACCEPTED_TOTAL}" -le 20 ]]; then
  SCALE=2
elif [[ "${ACCEPTED_TOTAL}" -gt 20 ]] && [[ "${ACCEPTED_TOTAL}" -le 40 ]]; then
  SCALE=4
elif [[ "${ACCEPTED_TOTAL}" -gt 40 ]] && [[ "${ACCEPTED_TOTAL}" -le 60 ]]; then
  SCALE=6
elif [[ "${ACCEPTED_TOTAL}" -gt 60 ]] && [[ "${ACCEPTED_TOTAL}" -le 80 ]]; then
  SCALE=8
elif [[ "${ACCEPTED_TOTAL}" -gt 80 ]] && [[ "${ACCEPTED_TOTAL}" -le 200 ]]; then
  SCALE=10
elif [[ "${ACCEPTED_TOTAL}" -gt 200 ]] && [[ "${ACCEPTED_TOTAL}" -le 400 ]]; then
  SCALE=20
elif [[ "${ACCEPTED_TOTAL}" -ge 400 ]]; then
  SCALE=40
fi

############################################################
# GNUPlot ISO values

# Do the following, if we have selected ISO related items in kdialog selection window.
if \
  [[ ${SEL1} == true ]] || \
  [[ ${SEL3} == true ]]
then
  
# ISO min max values

# 1) Use awk to print field 3 from RAWDATA_TMP. Ignore the first row with FNR> 1 option.
# 2) awk prints equivalent numbers as output. Merge them with "|sort -n" pipe.
#    sort prints numbers starting from the smallest (first line) and ending to the greatest (last line).
# 3) Strip the output, either first line (head -1) or the last one (tail -1).

  ISO_MIN_VALUE=$(echo -n $(awk -F ',' 'FNR> 1 {print $4}' "${RAWDATA_TMP}" | sort -n | head -1))
  ISO_MAX_VALUE=$(echo -n $(awk -F ',' 'FNR> 1 {print $4}' "${RAWDATA_TMP}" | sort -n | tail -1))

############################################################

# Get percentages for ISO values usage, generate RAWDATA_TMP2 file.

# OUTPUT template for RAWDATA_TMP3 is as follows:

# <count of ISO values>,<ISO value>,<percentage of specific ISO value usage in data> 

# Explanation for the following command:

# 1) Use awk to print field 3 from RAWDATA_TMP. Ignore the first row with FNR> 1 option.
# 2) awk prints equivalent numbers as output. Count and merge them with "|sort -n | uniq -c" pipe
# 3) Output results leading white spaces. For each line, delete them with sed.
# 4) use awk as pipe (awk starting with '{b[$2]=$1;sum=sum ...) to calculate percentage
#    for the first column. First column has count number for each ISO value ("how many times ISO XX is used").
#    ISOs are defined in column 2. Print the output to a new column 3.
# 5) In step 4, the output has too many decimals. As the output of this step is written to column 3,
#    we use another awk pipe to strip too many decimals of the current column 3.
#    To keep two first decimals, we use %.2f option. Print column 1 ($1) and 2 ($2) as they are,
#    respectively. Add % mark and start a new line (\n) after each printf function.
# 6) Replace spaces with commas for the final output, and write the final output to RAWDATA_TMP2.

  awk -F ',' 'FNR> 1 {print $4}' "${RAWDATA_TMP}" | \
    sort -n | \
    uniq -c | \
    sed "s/^[ \t]*//" | \
    awk '{b[$2]=$1;sum=sum+$1} END{for (i in b) print b[i],i,(b[i]/sum)*100}' | \
    awk '{printf "%.0f %.0f %.2f'%'\n", $1,$2,$3}' | \
    tr ' ' ',' \
  > "${RAWDATA_TMP2}"

####################################################################################################################

# ISO values - minimum, maximum, least used, most used, average

  # What is the maximum number of matches for a single ISO value?
  MAX_MATCH_FOR_ISO=$(echo -n $(awk -F ',' '{print $1}' "${RAWDATA_TMP2}" | sort -n | tail -1))

  # We store current min/max ISOvalues to a string variables

  # Returns column 3 value of RAWDATA_TMP E.G. 3200, based on max column 3 value of RAWDATA_TMP
  WHATIS_REAL_MAX_ISO=$(echo -en "Max: $ISO_MAX_VALUE")
  # Returns column 3 value of RAWDATA_TMP E.G. 200, based on min column 3 value of RAWDATA_TMP
  WHATIS_REAL_MIN_ISO=$(echo -en "Min: $ISO_MIN_VALUE")

  # Format: (1*400)+(1*1600)+(2*3200) ...
  ISO_DIVIDEND=$(
    echo -n $(
      ($(
        awk -F ',' '{print "("$1,$2")"}' "${RAWDATA_TMP2}" | \
        sort -n | \
        sed -e 's/ /*/g' | \
        tr '\n' '+' | \
        sed 's/+[^+]*$//'
      ))
    )
  )

  # Just a basic average calculation
  ISO_AVERAGE=$(
    echo -e $(
      awk 'BEGIN {print "'"$ISO_DIVIDEND"'"/"'"$ACCEPTED_TOTAL"'"}' | awk '{printf "%.0f", $1}'
    )
  )

##########################################################

# ISO VALUES - CHECK FOR MIN AND MAX VALUES

# 1) Get awk output of file RAWDATA_TMP3, separator for columns is comma mark, get column 3 ($3)
# 2) Sort percentage values from lowest to greatest, starting from the lowest
# 3) Get the match count for each percentage value (column 3 value) with 'uniq -c'
# 4) Trim all leading white spaces for each printed line
# 5) We have now two columns, separated by space. Get the first column with awk pipe,
#    use space as a column separator, and print column 1 ($1)
# 6) Get the first line. Output represents the number of matches for listed percentage.
#    We check if it's not 1 in the following if statement.

  # The whole idea is that we can't give a true statement for
  # "What is the least/most used ISO value" if multiple ISO values equal same percentage for usage

  MOSTUSED_ISO_CHECK=$(
    echo -n $(
      awk -F ',' '{print $3}' "${RAWDATA_TMP2}" | sort -n | uniq -c | sed "s/^[ \t]*//" | awk -F ' ' '{print $1}' | tail -1
    )
  )
  LEASTUSED_ISO_CHECK=$(
    echo -n $(
      awk -F ',' '{print $3}' "${RAWDATA_TMP2}" | sort -n | uniq -c | sed "s/^[ \t]*//" | awk -F ' ' '{print $1}' | head -1
    )
  )

  # The following gives a correct value ONLY IF there are unique values for EACH ISOs.
  # Otherwise, the output is not as expected. That's why we need to check the values
  # of MOST/LEASTUSED_ISO_CHECK first.
  MOSTUSED_ISO=$(
    echo -n $(
      awk -F ',' '{print $3,$2}' "${RAWDATA_TMP2}" | sort -n | awk -F ' ' '{print $2}' | tail -1
    )
  )
  LEASTUSED_ISO=$(
    echo -n $(
      awk -F ',' '{print $3,$2}' "${RAWDATA_TMP2}" | sort -n | awk -F ' ' '{print $2}' | head -1
    )
  )

##########################################################

# In addition, we consider that minimum of 10 pictures must be accepted as input.
# Otherwise, user can read this info pretty easily just checking the gnuplot graphs.

  # Least used ISO
  # If more than one, then
  if [[ "$LEASTUSED_ISO_CHECK" -ne 1 ]]
  then
    # Output string, nothing to say.
    WHATIS_LEASTUSED_ISO=$(echo -n "")

  # Else if it's one, then
  elif [[ "$LEASTUSED_ISO_CHECK" -eq 1 ]]
  then
    
    # We check the number of pictures. If it's greater than 10, then print the following string.
    if [[ "$ACCEPTED_TOTAL" -gt 10 ]]
    then
        
      # Returns column 2 value of RAWDATA_TMP2 E.G. 400, based on max column 3 value of RAWDATA_TMP2
      WHATIS_LEASTUSED_ISO=$(echo -n ", Least used: $LEASTUSED_ISO")
  
    # We check the number of pictures. If it's equal or less than 10, we print nothing.
    elif [[ "$ACCEPTED_TOTAL" -le 10 ]]
    then
      # Output string, nothing to say.
      WHATIS_LEASTUSED_ISO=$(echo -n "")
    fi
  fi

  # Most used ISO
  # If more than one, then
  if [[ "$MOSTUSED_ISO_CHECK" -ne 1 ]]
  then
    # Output string, nothing to say.
    WHATIS_MOSTUSED_ISO=$(echo -n "")

  # Else if it's one, then
  elif [[ "$MOSTUSED_ISO_CHECK" -eq 1 ]]
  then

    # We check the number of pictures. If it's greater than 10, then print the following string.
    if [[ "$ACCEPTED_TOTAL" -gt 10 ]]; then
      
      # Returns column 2 value of RAWDATA_TMP2 E.G. 400, based on max column 3 value of RAWDATA_TMP2
      WHATIS_MOSTUSED_ISO=$(echo -n ", Most used: $MOSTUSED_ISO")

    elif [[ "$ACCEPTED_TOTAL" -le 10 ]]
    then
      # We check the number of pictures. If it's equal or less than 10, we print nothing.
      WHATIS_MOSTUSED_ISO=$(echo -n "") #Output string, nothing to say
    fi
  fi

###########################################################

# ISO values - shift ISO range values for GNUPlot

# We shift down minimum ISO values to get a proper scale for gnuplot.
# Use "Less than" integer comparison because there can be ISO values such as 160, 250.

# DO NOT CHANGE THE CHECK ORDER!

  if [[ "${ISO_MIN_VALUE}" -le 100 ]]; then
    # Just scaling down, not a true ISO value
    ISO_MIN_VALUE_GNU=0
  elif [[ "${ISO_MIN_VALUE}" -le 200 ]]; then
    ISO_MIN_VALUE_GNU=100
  elif [[ "${ISO_MIN_VALUE}" -le 400 ]]; then
    ISO_MIN_VALUE_GNU=200
  elif [[ "${ISO_MIN_VALUE}" -le 800 ]]; then
    ISO_MIN_VALUE_GNU=400
  elif [[ "${ISO_MIN_VALUE}" -le 1600 ]]; then
    ISO_MIN_VALUE_GNU=800
  elif [[ "${ISO_MIN_VALUE}" -le 3200 ]]; then
    ISO_MIN_VALUE_GNU=1600
  elif [[ "${ISO_MIN_VALUE}" -le 6400 ]]; then
    ISO_MIN_VALUE_GNU=3200
  elif [[ "${ISO_MIN_VALUE}" -le 8000 ]]; then
    ISO_MIN_VALUE_GNU=6400
  fi

  if [[ "${ISO_MAX_VALUE}" -ge 8000 ]]; then
    ISO_MAX_VALUE_GNU=12800
  elif [[ "${ISO_MAX_VALUE}" -ge 6400 ]]; then
    ISO_MAX_VALUE_GNU=8000
  elif [[ "${ISO_MAX_VALUE}" -ge 3200 ]]; then
    ISO_MAX_VALUE_GNU=6400
  elif [[ "${ISO_MAX_VALUE}" -ge 1600 ]]; then
    ISO_MAX_VALUE_GNU=3200
  elif [[ "${ISO_MAX_VALUE}" -ge 800 ]]; then
    ISO_MAX_VALUE_GNU=1600
  elif [[ "${ISO_MAX_VALUE}" -ge 400 ]]; then
    ISO_MAX_VALUE_GNU=800
  elif [[ "${ISO_MAX_VALUE}" -ge 200 ]]; then
    ISO_MAX_VALUE_GNU=400
  elif [[ "${ISO_MAX_VALUE}" -ge 100 ]]; then
    ISO_MAX_VALUE_GNU=200
  fi

###########################################################

# Export all used ISO values
  GET_ISO_VALUES=$(
    echo -n $(
      awk -F ',' 'FNR> 1 {print $4}' "${RAWDATA_TMP}" | \
      awk '!seen[$0]++' | \
      sort -n | \
      tr '\n' ',' | \
      sed -e 's/,[^,]*$//'
    )
  )

  ISO_TICSRANGE=$(echo -n "${ISO_MIN_VALUE_GNU},${GET_ISO_VALUES,$ISO_MAX_VALUE_GNU}")

###########################################################

fi

###########################################################

# GNUPlot Temperature values

# Do the following, if we have selected temperature related items in kdialog selection window.
if [[ "${SEL3}" == true ]]; then

###########################################################

# RAWDATA_TMP3
# Get percentages for temperature values

# OUTPUT template for RAWDATA_TMP3 is as follows:

# <count for matching temperatures>,<temperature value>,<percentage of specific temperature in data> 

# Explanation for the following command:

# 1) Use awk to print field 2 from RAWDATA_TMP. Ignore the first row with FNR> 1 option.
# 2) awk prints equivalent numbers as output. Count and merge them with "|sort -n | uniq -c" pipe
# 3) Output results leading white spaces. For each line, delete them with sed.
# 4) use awk as pipe (awk starting with '{b[$2]=$1;sum=sum ...) to calculate percentage
#    for the first column. First column has count number for each temperature value
#    ("how many matches for XX temperature"). Temperature values are defined in column 2.
#    Print the output to a new column 3.
# 5) In step 4, the output has too many decimals. As the output of this step is written to column 3,
#    we use another awk pipe to strip too many decimals of the current column 3.
#    To keep two first decimals, we use %.2f option. Print column 1 ($1) and 2 ($2) as they are,
#    respectively. Add % mark and start a new line (\n) after each printf function.
# 6) Replace spaces with commas for the final output, and write the final output to RAWDATA_TMP3.

  awk -F ',' 'FNR> 1 {print $3}' "${RAWDATA_TMP}" | \
  sort -n | \
  uniq -c | \
  sed "s/^[ \t]*//" | \
  awk '{b[$2]=$1;sum=sum+$1} END{for (i in b) print b[i],i,(b[i]/sum)*100}' | \
  awk '{printf "%.0f %.0f %.2f'%'\n", $1,$2,$3}' | \
  tr ' ' ',' \
  > "${RAWDATA_TMP3}"

###########################################################

  # Temperature min max values (actual values from the file)
  TEMP_MIN=$(
    echo -n $(
      awk -F ',' 'FNR> 1 {print $3}' "${RAWDATA_TMP}" | sort -n | head -1
    )
  )
  TEMP_MAX=$(
    echo -n $(
      awk -F ',' 'FNR> 1 {print $3}' "${RAWDATA_TMP}" | sort -n | tail -1
    )
  )

  # Format: (1*31)+(1*38)+(2*39) ...
  TEMP_DIVIDEND=$(
    echo -n $(
      ($(
        awk -F ',' '{print "("$1,$2")"}' "${RAWDATA_TMP3}" | sort -n | sed -e 's/ /*/g' | tr '\n' '+' | sed 's/+[^+]*$//'
      ))
    )
  )

  # Just a basic average calculation
  TEMP_AVERAGE=$(echo -e $(awk 'BEGIN {print "'"$TEMP_DIVIDEND"'"/"'"$ACCEPTED_TOTAL"'"}' | awk '{printf "%.2f", $1}'))

###########################################################

  # What is the maximum number of matches for a single temperature?
  MAX_MATCH_FOR_TEMP=$(
    echo -n $(awk -F ',' '{print $1}' "${RAWDATA_TMP3}" | sort -n | tail -1)
  )

  # Round temperature scale.
  # Multiplier for temperature scale for plot 1.
  TEMP_MULTP=2 

  # Temperature increment steps. For example, with value of 2,
  # we get ...0, 2...10, 12, 14, 16...24... etc.
  # TEMP_INCREMENT=2

  # We set minimum temperature to <value> - 2, rounding down
  UNROUNDED_MIN=$(echo -n $((${TEMP_MIN} - ${TEMP_MULTP})))

  # Basic layout for the following awk stuff:
  # awk '{i=int($0/4);print((i==$0||$0>0)?i:i-1)*4}'
  # Ref: https://stackoverflow.com/questions/33085008/bash-round-to-nearest-multiple-of-4

  MINVALUE_TEMP=$(
    echo -n $UNROUNDED_MIN | \
      awk '{i=int("'"$UNROUNDED_MIN"'"/"'"$TEMP_MULTP"'");print((i=="'"$UNROUNDED_MIN"'"||"'"$UNROUNDED_MIN"'">0)?i:i-1)*"'"$TEMP_MULTP"'"}'
  )

  # We set maximum temperature to <value> + 2, rounding up
  UNROUNDED_MAX=$(echo -n $((${TEMP_MAX} + ${TEMP_MULTP})))

  # Basic layout for the following awk stuff:
  # awk '{print$0+(n-$0%n)%n}'
  # Ref: https://stackoverflow.com/questions/33085008/bash-round-to-nearest-multiple-of-4

  MAXVALUE_TEMP=$(
    echo -n $UNROUNDED_MAX | \
      awk '{print"'"$UNROUNDED_MAX"'"+("'"$TEMP_MULTP"'"-"'"$UNROUNDED_MAX"'"%"'"$TEMP_MULTP"'")%"'"$TEMP_MULTP"'"}'
  )

fi

###########################################################

# GNUPlot selection 3 - Temperatures & ISOs

###########################################################
# PLOT 1 (Images & Temperatures & ISOS)

if [[ "${SEL3}" == true ]]; then

# GNUPlot program execution starts here.

gnuplot <<EOF &

reset

###########################################################
#set title "$GNUPLOT_TITLE" font ",12" offset 0,1

#Set Window Title in Qt environment
set term qt title "$GNUPLOT_MAINWINDOW_TITLE"

set boxwidth 0.75

set style data histograms

set style fill solid border -1

#set xlabel "Image Files ($FIRST-$LAST)" noenhanced
set xlabel " " noenhanced #Just a dummy label placeholder
#set x2label "Time"
set ylabel "Temperature (°C) -- Avg: $TEMP_AVERAGE°C"
set y2label "ISO Value -- Avg: $ISO_AVERAGE"
set datafile separator ","
set grid
#set xtics font ",7"
#set x2tics

# We adapt the layout for number of files...
$X2_TIMESTRINGS
$X_ROTATELABELS

set yrange [$MINVALUE_TEMP:$MAXVALUE_TEMP]

set y2range [$ISO_MIN_VALUE_GNU:$ISO_MAX_VALUE_GNU]

#set xtics ($FILELIST)

set y2tics ($ISO_TICSRANGE)

set xrange [0:$ACCEPTED_TOTAL]
set autoscale x

##set timefmt '%Y-%m-%dT%H:%M:%S'
##set mouse mouseformat 3

#Write values as they are
set tics noenhanced font ",8"

#Don't consider the first line as data but as column titles?
set key autotitle columnhead

set palette model RGB
###########################################################

plot '${RAWDATA_TMP}' using 3:xtic(1) title 'Temperature' lc rgb "orange", \
$TEMP_AVERAGE title 'Temp Avg.' lc rgb "red", \
'' using 4:x2tic(sprintf("%s\n%s", stringcolumn(23), stringcolumn(24))) title 'ISO Value' lc rgb "blue" axis x1y2, \
$ISO_AVERAGE title 'ISO Avg.' lc rgb "black" axis x1y2

pause mouse close
EOF

###########################################################
# PLOT 2 & 3 (More temperature & ISO analysis)

# GNUPlot program execution starts here.

# This leads actually to a bug which kills qnuplot, making all zoom/grid etc.
# options unavailable. This is what we want for the following plots.
#
# The bug is discussed here: https://sourceforge.net/p/gnuplot/bugs/1419/
# And here: https://sourceforge.net/p/gnuplot/bugs/1483/

gnuplot --persist <<EOF &

reset

###########################################################
set term qt title "$GNUPLOT_MAINWINDOW_TITLE"
set multiplot layout 2, 1 title "ISO Speed Averages ($WHATIS_REAL_MIN_ISO, $WHATIS_REAL_MAX_ISO$WHATIS_LEASTUSED_ISO$WHATIS_MOSTUSED_ISO, Avg: $ISO_AVERAGE)" font ",10" 
#THIS IS A TOP LABEL FOR ISO SPEEDS!

# Max ISO string:           $WHATIS_REAL_MAX_ISO
# Min ISO string:           $WHATIS_REAL_MIN_ISO
# Least used ISO string:    $WHATIS_LEASTUSED_ISO
# Most used ISO string:     $WHATIS_MOSTUSED_ISO

#
###set x2label "ISO Speed Averages" font ",10" offset 0,-1
set ylabel "Image Count" font ",10"
set datafile separator ","
#set style data histogram
set style fill solid border -1
set boxwidth 0.40 relative
set palette model RGB
set yrange [0:$MAX_MATCH_FOR_ISO+1]
set ytics 0,$SCALE,$MAX_MATCH_FOR_ISO+1
set xtics rotate by 45 right
set x2tics offset 0,-0.4
#set offset 0,-2.00
#set xtics
#set xrange [$ISO_MIN_VALUE_GNU:$ISO_MAX_VALUE_GNU]
unset key
plot '${RAWDATA_TMP2}' using 1:xtic(2) title '$WHATIS_REAL_MAX_ISO' lc rgb "green" with boxes, \
'' using 1:x2tic(3) title '' with boxes fill empty
#
###unset x2label
unset xtics
set xtics
set xlabel "Temperature Averages (Avg: $TEMP_AVERAGE°C)" font ",10" #THIS IS A TOP LABEL FOR TEMPERATURES!
#set ylabel "Image Count" font ",10"
set datafile separator ","
#set style data histogram
set boxwidth 0.40 relative
set style fill solid border -1
set palette model RGB
set yrange [0:$MAX_MATCH_FOR_TEMP+1]
set ytics 0,$SCALE,$MAX_MATCH_FOR_TEMP+1
set x2tics offset 0,-0.4
unset key
plot '${RAWDATA_TMP3}' using 1:xtic(2) title '' lc rgb "red" with boxes, \
'' using 1:x2tic(3) title '' with boxes fill empty

#
unset multiplot
#
###########################################################
EOF

  sleep 5
  rm "${RAWDATA_TMP2}"
  rm "${RAWDATA_TMP3}"
fi

# GNUPLOT CODE - END

###########################################################

if [[ "${KEEPSTATS}" == false ]]
then
  rm "${RAWDATA_TMP}"
fi

exit 0
