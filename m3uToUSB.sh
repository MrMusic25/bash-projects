#!/bin/bash
#
# m3uToUSB - Script to convert all the songs in an m3u playlist to mp3 in an output directory
# A bash implementation of my Powershell script, for when bash is available on Windows
#
# Changes:
# v0.0.1
# - Initial commit
#
# v0.0.1, 17 Aug. 2016 11:14 PST

### Variables



### Functions

if [[ -f commonFunctions.sh ]]; then
	source commonFunctions.sh
elif [[ -f /usr/share/commonFunctions.sh ]]; then
	source /usr/share/commonFunctions.sh
else
	echo "commonFunctions.sh could not be located!"

	# Comment/uncomment below depending on if script actually uses common functions
	#echo "Script will now exit, please put file in same directory as script, or link to /usr/share!"
	#exit 1
fi

function convertSong() {

}

function checkDependencies() {
	# ffmpeg, libmp3lame, coreutils (because Windows), possibly exfat-utils
}

function displayHelp() {

}

function deleteOldSongs() {

}

function processArgs() {

}

### Main Script



#EOF