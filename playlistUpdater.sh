#!/bin/bash
source /usr/share/commonFunctions.sh

### Variables

usage="Usage: playlistUpdater.sh <folderOfPlaylists>\n"
prefix="/mnt" # Prefix for mounted NTFS drive 

### Functions

function convertPlaylist() {
	if [[ -z $1 ]]; then
		debug "l2" "ERROR: Incorrect call for convertPlaylist()!"
		return 1
	fi
	
	# Set playlist name, check to make sure it exists
	local playlistName="$(echo "$1" | rev | cut -d'.' -f1 --complement | rev)"
	if [[ -z $playlistName ]]; then
		debug "l2" "FATAL: No playlist name found with $1 !"
		return 1
	fi
	
	# Convert!
	if [[ "$playlistName" == [Aa]lbum* ]]; then
		# Album specific options
		m2u -p b -f "$prefix" -n -c "$1" "$(pwd)"
	else
		# Everything else
		mkdir "$playlistName"
		m2u -p n -f "$prefix" -n -c "$1" "$playlistName"
	fi
}

### Main script

# Error checking
if [[ -z $(which m2u 2>/dev/null) ]]; then
	debug "l2" "ERROR: m3u2USB shortcut has not been setup! Please locate and link to /usr/bin!"
	echo "$usage"
	exit 1
fi

debug "l3" "INFO: Attempting to convert all playlists in $(pwd)!"

# If $1 is a folder, change into it first. Else, assume current directory
if [[ -d "$1" ]]; then
	debug "l2" "WARN: Using given argument $1 as m3u directory"
	OPWD="$(pwd)"
	cd "$1"
fi

for file in *.m3u;
do
	convertPlaylist "$file"
done

cd "$OPWD"
debug "l3" "INFO: Done converting playlists from folder!"

#EOF