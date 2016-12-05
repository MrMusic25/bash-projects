#!/bin/bash
#
# m3uToUSB - Script to convert all the songs in an m3u playlist to mp3 in an output directory
# A bash implementation of my Powershell script, for when bash is available on Windows
#
# Changes:
# v1.0.1
# - Small changes, forgot to run it through shellcheck
# - for loop in processArgs() seems to be preventing it from working now, update to this will come tomorrow
#
# v1.0.0
# - Ready for release!
# - Added converterLoop(), which does the actual work. Will find a way to parallel-ize this in a later version
# - convertSong() will now copy if the song is mp3 or unconvertible, sending a debug message for the latter
#
# v0.5.0
# - Added -c | --clean-numbers option to get rid of numbers in output song titles
# - Created outputFilename(), to be used like win2UnixPath() but for the output name. Handles artist, album, folder checks, and numbers
# 
# v0.4.0
# - Added code to remove trailing '/' from prefix and outputFolder, if it exists
# - Added touchTest() to easily check if user has write permissions for folder
# - Added error checking for outputFolder, and offer to make folder if non-existent
#
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
# - Option to convert input m3u with w2u and output to a new m3u file
#   ~ Copy both to output folder...?
# - Display percentage done every 15 or 30 seconds, so user sees progress (hopefully not an async process...)
#   ~ Possibly get some file conversion time averages and estimate time to completion?
#
# v1.0.1, 04 Dec. 2016 02:39 PST

### Variables

declare -a filePaths # Original paths from the m3u file
declare -a convertedPaths # Paths that have been converted for use with win2UnixPath()
m3uFile="" # Self-explanatory
outputFolder="" # I only put a comment here to make it look nice
prefix="" # If the path needs to be changed
w2uMode="" # Change this to 'upper' or 'cut' if needed, see win2UnixPath() documentation for more info
bitrate=128 # Explanatory
preserveLevel="artist" # Artist folder will be saved by default. Also works with album, or none
ffmpegOptions="" # Random options to be thrown in 
timeoutVal="120s" # Time to wait before assuming a conversion has failed
numberDelimiter=' ' # Defaults to a space, but can be changed by user if needed

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
	
	# Warn user of unconvertible files
	if [[ "$1" == *.m4p ]]; then
		debug "l2" "WARNING: File $1 contains DRM! This file cannot be converted an will be copied instead!"
		cp "$1" "$2"
		return $?
	fi
	
	# If song is already MP3, copy instead of trying to convert
	if [[ "$1" == *.mp3 ]]; then
		cp "$1" "$2"
		return $?
	fi
	
	#timeout --foreground -k "$timeoutVal" 
	ffmpeg -i "$1" -codec:a libmp3lame -b:a "$bitrate" -id3v2_version 3 -write_id3v1 1 "$ffmpegOptions" "$2"
	value=$?
	if [[ $value -ne 0 ]]; then
		debug "l2" "An error ocurred while converting $1 . Exit status: $value"
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
   -c | --clean-numbers [delimiter]              : Deletes anything before delimiter in output file (gets rid of numbers before song titles)
                                                 : Delimiter not required, set to space by default. Besure to encase delimiter in ''!
   
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
	
	while [[ -z $outputFolder ]];
	do
		arg="$1"
		
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
			-c|--clean-numbers)
			noNumbers="true"
			if [[ $2 == \'* ]]; then # Starts with a '
				numberDelimiter=$2 # Quotes might break this one, needs testing
			fi
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
			if [[ "$prefix" == */ ]]; then
				prefix="$(echo "$prefix" | rev | cut -d'/' -f 1 --complement | rev)" # Cuts the trailing slash, if present, to prevent errors
			fi
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
	exit 0
}

function touchTest() {
	touch "$1"
	estatus=$?
	case "$estatus" in
		0)
		debug "Folder $1 passed the touch test!"
		;;
		*)
		debug "l2" "ERROR: You do not have write permission for the folder $1 ! Please fix, or select a different folder, and re-run!"
		displayHelp
		exit $estatus
		;;
	esac
}

# outputFilename "input file"
# Everything else is taken from global variables, which should already be set
function outputFilename() {
	# Just to be sure...
	[[ -z $1 ]] && debug "ERROR: No argument supplied to outputFilename!" && return
	
	artistFolder="$(echo "$1" | rev | cut -d'/' -f3 | rev)"
	albumFolder="$(echo "$1" | rev | cut -d'/' -f2 | rev)"
	fileName="$(echo "$1" | rev | cut -d'/' -f 1 | rev | cut -d'.' -f1)"".mp3" # Wasted cycles, but who cares with today's processors?
	[[ ! -z $noNumbers ]] && fileName="$(echo "$fileName" | cut -d '$numberDelimiter' -f1 --complement)" # I was gonna save this for a later date, but the implementation was simple
	
	case "$preserveLevel" in
		none)
		newFile="$outputFolder"/"$fileName"
		;;
		artist)
		newFile="$outputFolder"/"$artistFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			[[ $# -eq 0 ]] || debug "l2" "ERROR: Unable to create folder: $newFile ! Please fix and re-run!"; exit 1 # Simple error checking
		fi
		newFile="$newFile""$fileName"
		;;
		album)
		# Artist folder first
		newFile="$outputFolder"/"$artistFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			[[ $# -eq 0 ]] || debug "l2" "ERROR: Unable to create folder: $newFile ! Please fix and re-run!"; exit 1 # Simple error checking
		fi
		
		# Now, check album folder
		newFile="$newFile"/"$albumFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			[[ $# -eq 0 ]] || debug "l2" "ERROR: Unable to create folder: $newFile ! Please fix and re-run!"; exit 1 # Simple error checking
		fi
		newFile="$newFile"/"$fileName"
		;;
		*)
		debug "l2" "A fatal error has occurred! Unknown preserve level: $preserveLevel!"
		exit 1
		;;
	esac
	
	# Now that that's all over with and output file is ready with working directories
	echo "$newFile"
}

function converterLoop() {
	announce "Beginnning conversion progress!" "This will take a while depending on processor speed and playlist length." "This screen will only show errors, but will notify you when it is complete."
	sleep 3
	
	for songFile in "${convertedPaths[@]}"
	do
		#if [[ ! -f "$songFile" ]]; then
		#	#echo "songFile: $songFile"
		#	debug "l2" "WARNING: could not find file: $songFile"
		#	continue
		#fi
		
		currentFile="$(outputFilename "$songFile")"
		# If anyone ever asks why I love functions, I will show them this. 
		# The function right here is the reason I love programming (or scripting, to be more specific)
		convertSong "$songFile" "$currentFile"
	done
}

### Main Script

processArgs "$@"
#testImport
checkRequirements "ffmpeg" #"libmp3lame0" #"moreutils"
[[ -z $overwrite ]] && ffmpegOptions="$ffmpegOptions ""-y"

# Error checking for outputFolder should only trigger if it is not a valid directory
if [[ ! -d "$outputFolder" ]]; then
	debug "l2" "ERROR: $outputFolder is not a directory!"
	getUserAnswer "Would you like to attempt to make this directory? (Be careful!)"
	case $? in
		0)
		debug "Attempting to create directory..."
		mkdir "$outputFolder"
		value=$?
		case $value in
			0)
			debug "l3" "Folder $outputFolder created successfully! Moving on..."
			;;
			*)
			debug "l2" "Error while attemping to create folder: exit status $value"
			announce "Please fix the error and re-run the script!"
			displayHelp
			exit $value
			;;
		esac
		;;
		1)
		debug "User decided not to make new folder, exiting script..."
		announce "Please find another directory and re-run the script!"
		displayHelp
		exit 1
		;;
		*)
		debug "l2" " ERROR: Unknown exit status!"
		displayHelp
		exit 1
		;;
	esac
fi
touchTest "$outputFolder"
if [[ "$outputFolder" == */ ]]; then # If it made it this far, folder is ready for use. Cut trailing slash if present
	outputFolder="$(echo "$outputFolder" | rev | cut -d'/' -f 1 --complement | rev)"
fi

# Ready to start converting. Import files, then loop!
importM3U
converterLoop

announce "Script has completed successfully!" "Please consult log for any file that could not be converted!"

#EOF