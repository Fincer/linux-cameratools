#!/bin/env bash

#    Geotag images
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

# TODO Coordinate threshold = Grid size is 30x30m?
# TODO Find API for ASTER DEM v2 (provides better data)

# Username for REST API data request
USERNAME=<PUT_YOUR_USERNAME_HERE>

############################

# Ping openstreetmap.org three times.
PING_ADDRESS="nominatim.openstreetmap.org"
INTERNET_TEST=$(ping -c 3 "${PING_ADDRESS}" 2>&1 | grep -c "unknown host")

if [[ ! "${INTERNET_TEST}" -eq 0 ]]
then
  echo -e "\nCan't connect to the Geo Service provider '${PING_ADDRESS}'. Please check your internet connection and try again.\n"
  exit 1
fi

############################

for IMAGE in $(echo "${@}")
do

  IMAGE_BASENAME=$(basename "${IMAGE}" | cut -f 1 -d '.')
  IMAGE_EXTENSION=$(echo $(basename "${IMAGE}" | cut -f 2 -d '.' | sed '/^\s*$/d'))

  if [[ $(exiftool -n -p '$GPSLatitude,$GPSLongitude' "${IMAGE}" | awk -F ',' '{print NF}') != 2 ]]
  then
    echo -e "$IMAGE_BASENAME: Missing coordinates. Are you sure you have geotagged the photo?\n"
    exit 0
  else

    LATITUDE=$(exiftool -n -p '$GPSLatitude' "${IMAGE}")
    LONGITUDE=$(exiftool -n -p '$GPSLongitude' "${IMAGE}")

    # Clear previous geonames information.
    exiftool \
      -Location= \
      -LocationShownCity= \
      -LocationShownCountryName= \
      -LocationShownProvinceState= \
      -LocationShownSublocation= \
      -Country-PrimaryLocationName= \
      -Sub-location= \
      -Country= \
      -City= \
      -State= \
      -Province-State= \
      -GPSAltitude= \
      "${IMAGE}" \
      -overwrite_original

    echo -e "$IMAGE_BASENAME: retrieving country information.\n"
    reversegeo "${IMAGE}"

    # Reference: http://www.geonames.org/export/web-services.html
    # Get elevation by retrieving a ASTER DEM value from GeoNames API server, grid size 30x30m
    # There are several error factors:
      # DEM Grid size
      # General inaccurancies in DEM model
      # Geoid model & projection errors
      # Coordinate errors
      # Variations in (estimated) height values

    # So the retrieved elevation value is just a rough estimation here.

    ALTITUDE=$(curl -s "http://api.geonames.org/astergdem?lat=$LATITUDE&lng=$LONGITUDE&username=$USERNAME")

    # If we have a successful answer, then
    if [[ "${ALTITUDE}" =~ '^[0-9]+$' ]]
    then

      exiftool -GPSAltitude="${ALTITUDE}" "${IMAGE}" -overwrite_original
      echo -e "${IMAGE_BASENAME}: Altitude value updated.\n"

    else
      # TODO: If not successful, try again for 2 times, then abort.
      echo -e "${IMAGE_BASENAME}: Couldn't retrieve altitude value.\n"
    fi
  fi
done
