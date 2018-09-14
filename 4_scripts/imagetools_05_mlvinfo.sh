#!/bin/bash

#    Show MLV file info in kdialog window (KDE/Plasma DE)
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

kdialog --msgbox "$(mlv_dump $1 2>&1 | grep -E 'opened|frames' | awk '{print $2}' | sed 's/.*\///' | sed -e '1 i\Files:' -e '4 i\\nDNG Frames:' )" --title "MLV Information";
