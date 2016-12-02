#!/bin/bash
#
# m3uToUSB - Script to convert all the songs in an m3u playlist to mp3 in an output directory
# A bash implementation of my Powershell script, for when bash is available on Windows
#
# Changes:
# v0.3.0
# - Filled out displayHelp()
# - processArgs() is ready
# - convertSong() is ready
# - Decided to add timeout options and error checking to convertSong()
#
# v0.2.0
# - Added testImport(), containing the code I used to successfully test importM3U()
# - Changed importM3U() so that it tests for validity before converting, as it takes a LOT of cycles to complete
# - Function also warns user that conversion process will take time
#
# v0.1.0
# - Added multiple function definitions in prep for what's to come
# - Untested version of importM3U() made with a new method I found
# - Added a check for ffmpeg and moreutils (planning on doing parallel processing for increased speed)
#
# v0.0.1
# - Initial commit
#
# TODO:
# - -i | --include option - Output the m3u file to the top level directory when finished
# - Great idea from this website to convert files in parallel, quick conversion! Requires ffmpeg, and moreutils
#   ~ https://wiki.archlinux.org/index.php/Convert_Flac_to_Mp3
# - No real reason for it, but let user change timeout val from commandline?
#   ~ Easy implementation, but displayHelp gets pretty long
#
# v0.3.0, 02 Dec. 2016 00:41 PST

### Variables

declare -a filePaths # Original paths from the m3u file
declare -a convertedPaths # Paths that have been converted for use with win2UnixPath()
m3uFile="" # Self-explanatory
outputFolder="" # I only put a comment here to make it look nice
prefix="" # If the path needs to be changed
w2uMode="" # Change this to 'upper' or 'cut' if needed, see win2UnixPath() documentation for more info
bitrate=128
preserveLevel="artist" # Artist folder will be saved by default. Also works with album, or none
ffmpegOptions="" # Random options to be thrown in 
timeoutVal="120s" # Time to wait before assuming a conversion has failed

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

# convertSong "inputFile" "outputFile"
# Function does NOT add prefixes, edit titles, etc... Only handle conversion using timeout!
function convertSong() {
	# Check if the bitrate has a 'k' in it for functionality
	if [[ "$bitrate" != *k ]]; then
		bitrate="$bitrate""k"
	fi
	
	timeout --foreground -k "$timeoutVal" ffmpeg -i "$1" -codec:a libmp3lame -b:a "$bitrate" -id3v2_version 3 -write_id3v1 1 "$ffmpegOptions" "$2"
	value=$?
	if [[ $value -ne 0 ]]; then
		debug "l2" "An error ocurred while converting $1 ! Exit status: $value"
	fi
}

function displayHelp() {
read -d '' helpVar <<"endHelp"
m3uToUSB.sh - A script to convert a text playlist of songs to MP3
NOTE: Files with DRM will be copied instead of converted, and you will be notified

Usage: m3uToUSB.sh [options] <playlist_file.m3u> <output_folder>

Options:
   -h | --help                                   : Display this help message and exit
   -p | --preserve <[A]rtist,al[B]um,[N]one>     : Tells script to preserve the artist, album, or no folders (artist default)
   -d | --delete                                 : Delete songs no longer in playlist (COMING SOON)
   -b | --bitrate <bitrate>                      : Output MP3 bitrate. Default 128 kbps (96, 128, 192, 256, and 320 are common values)
   -e | --edit-path-mode <[U]pper,[C]ut>         : Leaves the Windows root uppercase, or cuts it out (see documentation)
   -f | --prefix <folder_prefix>                 : Adds the prefix to each m3u line if it is a Windows path (/mnt, /media)
   -n | --no-overwrite                           : Disables overwriting of conflicting files
   
Not limited to .m3u files, any newline delimited file works as well!
Windows paths will be converted automatically, useful if running on Bash for Windows

A common use for Bash on Windows would be:
   m3uToUSB.sh --prefex /mnt music.m3u /dev/sdb1
endHelp
echo "$helpVar"
}

function deleteOldSongs() {
debug "User chose to delete old songs! Running..."
}

function processArgs() {
	if [[ "$1" == "-h" || "$1" == "--help" ]]; then
		displayHelp
		exit 0
	elif [[ $# -lt 2 ]]; then
		debug "l2" "ERROR: Not enough arguments!"
		displayHelp
		exit 1
	fi
	
	for arg in "$@"
	do
		# Minimum two arguments - .meu and output folder. Check validity and move on if so
		if [[ -f "$arg" ]]; then
			if [[ -d "$2" ]]; then
				# Only successful case. Nested because it makes reporting errors easier
				m3uFile="$arg"
				outputFolder="$2"
				return # Slightly messy, but there shouldn't be any arguments after this anyways
			else # Bad output folder
				debug "l2" "ERROR: Output folder $2 is invalid or non-existent! Please fix and re-run!"
				displayHelp
				exit 1
			fi
		else
			debug "l2" "ERROR: Invalid playlist file $arg given! Please fix and re-run!"
			displayHelp
			exit 1
		fi	
		
		# If the previous block wasn
		case "$arg" in
			-h|--help)
			displayHelp
			exit 0
			;;
			-p|--preserve)
			case "$2" in
				a*|A*)
				true # Default, nothing to be done
				;;
				b*|B*)
				preserveLevel="album"
				;;
				n*|N*)
				preserveLevel="none"
				;;
				*)
				debug "l2" "ERROR: Unknown preserve level: $2 ! Please fix and re-run!"
				displayHelp
				exit 1
				;;
			esac
			shift
			;;
			-d|--delete)
			deleteMode="1" # If var is present, run deleteOldSongs(). This value could technically be anything
			;;
			-n|--no-overwrite)
			overwrite="off"
			debug "User has turned off overwriting filed by default"
			;;
			-b|--bitrate)
			bitrate="$2" # Putting a lot of faith in the user
			debug "User set bitrate to: $bitrate"
			shift
			;;
			-e|--edi*)
			case "$2" in
				u*|U*)
				w2uMode="upper"
				debug "User has indicated to use upper with win2UnixPath()"
				;;
				c*|C*)
				w2uMode="cut"
				debug "User has indicated to use cut with win2UnixPath()"
				;;
				*)
				debug "l2" "ERROR: Invalid option eiven with $arg : $2 ! Please fix and re-run!"
				displayHelp
				exit 1
				;;
			esac
			shift
			;;
			-f|--prefix)
			if [[ ! -d "$2" ]]; then
				debug "l2" "ERROR: $2 is not a valid prefix folder! Please fix and re-run!"
				displayHelp
				exit 1
			fi
			prefix="$2"
			shift
			;;
			*)
			# Minimum two arguments - .m3u and output folder. Check validity and move on if so
			if [[ -f "$arg" ]]; then
				[[ -z $2 ]] && debug "l2" "ERROR: No output directory given! Please fix and re-run!" && displayHelp && exit 1 # One-liners are the best
				m3uFile="$arg"
				outputFolder="$2" # Assuming it is a directory for now, will be checked later
				return # Slightly messy, but there shouldn't be any arguments after this anyways
			fi
			debug "l2" "ERROR: Unknown option given: $arg ! Please fix and re-run!"
			displayHelp
			exit 1
			;;
		esac
		shift
	done
}

function importM3U() {
	# Import the whole m3u file into an array, since it might need to be used multiple times
	# http://stackoverflow.com/questions/21121562/shell-adding-string-to-an-array
	
	announce "Now preparing files for conversion..." "This process may take a minute depending on CPU power and playlist size"
	while read -r line
	do
		[[ "$line" == \#* ]] && continue # Skip the line if it starts with a '#'
		filePaths+=("$line")
	done < "${m3uFile}"
	
	# Now that the lines are imported, make sure they are all Linux-friendly
	for path in "${filePaths[@]}"
	do
		if [[ -f "$path" ]]; then
			convertedPaths+=("$path") # This should save a lot of time with native Linux m3u files
		else
			convertedPaths+=("$(win2UnixPath "$path" "$w2uMode")")
		fi
	done
}

function testImport() {
	#if [[ -z $1 || ! -f "$1" ]]; then
	#	echo "Please run with a file!"
	#	exit 1
	#fi

	#m3uFile="$1"
	importM3U

	echo " "
	echo "Showing contents of filePaths..."
	pause
	for item in "${filePaths[@]}"
	do
		echo "$item"
	done

	pause

	echo " "
	echo "Showing contents of convertedPaths..."
	pause
	for items in "${convertedPaths[@]}"
	do
		echo "$items"
	done
}

### Main Script

processArgs "$@"
checkRequirements "ffmpeg" "libmp3lame0" #"moreutils"
[[ -z $overwrite ]] && ffmpegOptions="$ffmpegOptions ""-y"


#EOF