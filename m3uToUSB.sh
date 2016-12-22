#!/bin/bash
#
# m3uToUSB - Script to convert all the songs in an m3u playlist to mp3 in an output directory
# A bash implementation of my Powershell script, for when bash is available on Windows
#
# Changes:
# v1.1.7
# - Small change so that Song titles with a '.' in the name wouldn't get cut off (07.Mz. Hyde.mp3 -> 07 Mz.mp3)
#
# v1.1.6
# - Testing shows everything works properly, Windows has some errors though... Assuming everything is fine though
# - First major release! Everything works!
#
# v1.1.5
# - processFailures() is ready for testing
#
# v1.1.4
# - Changed some debugging messages to make reading the log easier
# - Added outputFailures() function, outputs them to a file for debugging purposes
# - Added determinePath(), basically a condensed version of fileVerifier.sh
#
# v1.1.3
# - clean-numbers option is tested and works (now)
# - Small change to how outputDirectory is evaluated
# - Added fileTest() to more easily check if file conversion was successful, along with calls
#
# v1.1.2
# - Added folderTest() because my current error checking for files was producing too many errors
# - Implemented above function
#
# v1.1.1
# - Functional changes; copying works, but conversion does not
#
# v1.1.0
# - Solved all my problems with one line. Added a dependency, but THE SCRIPT WORKS NOW!
# - All other changes are classified as minor text fixes
# - Added unlisted option --test-import to test importing and filenames, see testImport()
# - Didn't add it earlier, but timeout is disabled until I have time to get it working (it was giving me weird errors)
# - -c option won't edit song titles that don't start with a number
# - Added delta conversion, once againt a much easier implementation than I remember on Powershell
#
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
# - BIG ONE: If song exists, skip it
# - reconvert() - Add "failed" files to an array, and try to convert them again in case there was a weird error
# - Make it so CTRL+C adds current song to failedSongs[], then passes signal to ffmpeg (for broken conversions)
# - Create a file called ~/.m2uSettings.conf that gets preloaded.
#   ~ Keeps settings like prefix, output folder, defaults, etc.
# - For -d|--delete - Copy over current m3u, and compare m3u files to see what changed, and delete changes
# - Make 'secret' or 'unlisted' options only double options and list them in displayHelp()
#   ~ e.g: only --update instead of -u|--update
#   ~ Useful for things like minor script options. Also useful in other scripts
#   ~ This almost makes it worth figuring out manpages...
#
# v1.1.7, 16 Dec. 2016 16:10 PST

### Variables

declare -a filePaths # Original paths from the m3u file
declare -a convertedPaths # Paths that have been converted for use with win2UnixPath()
declare -a failedSongs # Songs that fail to convert will be placed here, decide what to do with them later
m3uFile="" # Self-explanatory
outputFolder="" # I only put a comment here to make it look nice
prefix="" # If the path needs to be changed
w2uMode="" # Change this to 'upper' or 'cut' if needed, see win2UnixPath() documentation for more info
bitrate=128 # Explanatory
preserveLevel="artist" # Artist folder will be saved by default. Also works with album, or none
ffmpegOptions="" # Random options to be thrown in 
timeoutVal="120s" # Time to wait before assuming a conversion has failed
numberDelimiter=' ' # Defaults to a space, but can be changed by user if needed
total=0 # Total number of songs
songsConverted=0

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
	
	# Complain if there are not enough arguments
	if [[ "$#" -ne 2 ]]; then
		if [[ -z $1 ]]; then
			debug "l2" "FATAL: No arguments present for convertSong()! Returning..."
			return
		elif [[ -z $2 ]]; then
			debug "l2" "FATAL: Only one argument given, $1 ! Returning..."
			return
		else
			debug "l2" "ERROR: More than two arguments given!"
			debug "l2" "Attempting to run with 1 = $1, 2 = $2"
		fi
	fi
	
	# Check to see if file exists already; delta conversion
	if [[ -f "$2" ]]; then
		debug "l5" "File $2 already exists! Skipping..." # Was originally "l1", but changed to l5 because log was WAY too large after each run
		return 0
	fi
	
	# Warn user of unconvertible files
	if [[ "$1" == *m4p ]]; then
		debug "l2" "WARNING: File $1 contains DRM! This file cannot be converted an will be copied instead!"
		cp "$1" "$2"
		return $?
	fi
	
	# If song is already MP3, copy instead of trying to convert
	if [[ "$1" == *mp3 ]]; then
		debug "l5" "$1 is an MP3, copying instead of converting"
		cp "$1" "$2"
		return $?
	fi
	
	debug "l5" "Converting $1 to $2"
	#timeout --foreground -k "$timeoutVal" 
	ffmpeg "$ffmpegOptions" -i "$1" -codec:a libmp3lame -b:a "$bitrate" -id3v2_version 3 -write_id3v1 1 "$2" &>/dev/null
	value=$?
	if [[ $value -ne 0 ]]; then
		debug "l2" "An error ocurred while converting $1 . Exit status: $value"
	fi
	return "$value"
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
				b*|B*|album|Album)
				preserveLevel="album"
				;;
				a*|A*)
				true # Default, nothing to be done
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
				shift
			fi
			;;
			--test-import|--testImport)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No file given to test importing!"
				displayHelp
				exit 1
			fi
			m3uFile="$2"
			testImport
			exit 0
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
	dos2unix "$m3uFile"
	
	while read -r line
	do
		[[ "$line" == \#* ]] && continue # Skip the line if it starts with a '#'
		filePaths+=("$line")
		((total++))
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
		printf "Is it a file? "
		if [[ -f "$items" ]]; then
			printf "True\n"
		else
			printf "False\n"
		fi
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
	
	# First, we create the variables. Then, we use them based on user decision
	artistFolder="$(echo "$1" | rev | cut -d'/' -f3 | rev)"
	albumFolder="$(echo "$1" | rev | cut -d'/' -f2 | rev)"
	fileName="$(echo "$1" | rev | cut -d'/' -f1 | cut -d'.' -f1 --complement | rev)"".mp3" # Wasted cycles, but who cares with today's processors?
	[[ ! -z $noNumbers ]] && [[ "$fileName" == [0-9]* ]] && fileName="$(echo "$fileName" | cut -d "$numberDelimiter" -f1 --complement)" # I was gonna save this for a later date, but the implementation was simple
	
	case "$preserveLevel" in
		none)
		newFile="$outputFolder"/"$fileName"
		;;
		artist)
		newFile="$outputFolder"/"$artistFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			#[[ "$#" -eq 0 ]] || debug "l2" "ERROR: Unable to create folder: $newFile ! Please fix and re-run!" # Simple error checking
			folderTest "$newFile"
		fi
		newFile="$newFile"/"$fileName"
		;;
		album)
		# Artist folder first
		newFile="$outputFolder"/"$artistFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			folderTest "$newFile"
		fi
		
		# Now, check album folder
		newFile="$newFile"/"$albumFolder"
		if [[ ! -d "$newFile" ]]; then
			mkdir "$newFile"
			folderTest "$newFile"
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
	
	shopt -s nocasematch
	shopt -s nocaseglob
	for songFile in "${convertedPaths[@]}"
	do
		if [[ ! -f "$songFile" ]]; then
			#echo "songFile: $songFile"
			debug "l2" "WARNING: Source file not found: $songFile"
			failedSongs+=("$songFile") # Place files not found in this array
			continue
		fi
		
		currentFile="$(outputFilename "$songFile")"
		# If anyone ever asks why I love functions, I will show them this. 
		# The function right here is the reason I love programming (or scripting, to be more specific)
		convertSong "$songFile" "$currentFile"
		if fileTest "$currentFile" # Only really reports the error... Better logging this way
		then
			((songsConverted++))
		fi
	done
}

function folderTest() {
	if [[ ! -d "$1" ]]; then
		debug "l2" "$1 is not a directory! mkdir failed, or insufficient permissions!"
		return 1
	fi
	return 0
}

function fileTest() {
	if [[ ! -f "$1" ]]; then
		debug "l2" "WARNING: File $1 could not be found, conversion failure!"
		return 1
	fi
	return 0
}

function outputFailures() {
	printf "\n\nFailed songs from playlist %s:\n" "$(echo "$m3uFile" | rev | cut -d'/' -f1 | rev)" >> failedSongs.txt
	for failure in "${failedSongs[@]}"
	do
		echo "$failure" >> failedSongs.txt
	done
	debug "l2" "List of failed songs has been output to $(pwd)/failedSongs.txt at user request!"
}

function determinePath() {
	# Now, try to 'find' these files
	artistFolder="$(echo "$1" | rev | cut -d'/' -f3 | rev)"
	albumFolder="$(echo "$1" | rev | cut -d'/' -f2 | rev)"
	fileName="$(echo "$1" | rev | cut -d'/' -f1 | rev)"
	container="$(echo "$1" | rev | cut -d'/' -f1-3 --complement | rev)"
	extension="$(echo "$fileName" | rev | cut -d'.' -f1 | rev)" # the rev's in this one make sure periods in filename don't get cut
	fileName="$(echo "$fileName" | rev | cut -d'.' -f1 --complement | rev)" # Same reason as above
	
	# First, check container
	if [[ -d "$container" ]]; then
		true
	else
		debug "l2" "ERROR: Bad folder container: $container"
		return 1
	fi
		
	# Artist folder
	testPath="$container"/"$artistFolder"
	if [[ -d "$testPath" ]]; then
		true
	else
		# Problem with the artist folder (rare)
		# Now see if running through 'title' makes it work
		artistFolder="$(echo -e "$artistFolder" | sed -r 's/\<./\U&/g')"
		testPath="$container"/"$artistFolder"
		if [[ -d "$testPath" ]]; then
			true
		else
			# No cutting the name here, might cause errors
			testPath="$(find "$container" -iname "$artistFolder*" -print0)"
			if [[ -d "$testPath" ]]; then
				artistFolder="$(echo "$testPath" | rev | cut -d'/' -f1 | rev)"
			else
				debug "l2" "ERROR: Could not locate artist folder: $artistFolder !"
				return 1
			fi
		fi
	fi
	
	# Album folder
	testPath="$container"/"$artistFolder"/"$albumFolder"
	if [[ -d "$testPath" ]]; then
		true
	else
		# Problem with album folder (most common)
		# Now see if running through 'title' makes it work
		albumFolder="$(echo -e "$albumFolder" | sed -r 's/\<./\U&/g')"
		testPath="$container"/"$artistFolder"/"$albumFolder"
		if [[ -d "$testPath" ]]; then
			# Worked, now see if fixed album+fileName works
			testPath="$testPath"/"$fileName"."$extension"
			if [[ -f "$testPath" ]]; then
				echo "$testPath"
				return 0
			else
				false # Now folder is present, but filename may be wrong
			fi
		else
			# Folder still not found, multiple errors maybe?
			# See if 'find' can find folder
			testPath="$(find "$container/$artistFolder" -iname "$(echo "$albumFolder" | cut -d' ' -f1)*" -print0)"
			if [[ -d "$testPath" ]]; then
				# Find was able to find the folder in question
				albumFolder="$(echo "$testPath" | rev | cut -d'/' -f1 | rev)"
				testPath="$container"/"$artistFolder"/"$albumFolder"/"$fileName"."$extension"
				if [[ -f "$testPath" ]]; then
					# File was found in 'found' folder!
					echo "$testPath"
					return 0
				else
					false # Still an issue with filename, directory is good though so move on
				fi
			else
				debug "l2" "ERROR: Album folder $albumFolder could not be found in parent $artistFolder !"
				return 1
			fi
		fi
	fi
	
	# If you made it this far, only option left is bad filename
	# First, attempt to fix case (usually the issue)
	fileName="$(echo -e "$fileName" | sed -r 's/\<./\U&/g')"
	testPath="$container"/"$artistFolder"/"$albumFolder"/"$fileName"."$extension"
	if [[ -f "$testPath" ]]; then
		echo "$testPath"
		return 0
	else
		# Fixing case of file did not work, now try to find based on first word or number
		testPath="$(find "$container/$artistFolder/$albumFolder" -iname "$(echo "$fileName" | cut -d' ' -f1)*" -print0)"
		if [[ -f "$testPath" ]]; then
			# Hope you got the right file!
			echo "$testPath"
			return 0
		else
			# File could not be found anywhere
			debug "l2" "FATAL: File could not be located: $testPath , giving up on it!"
			return 1
		fi
	fi
}

function processFailures() {
	announce "Now attempting to process files that gave errors during conversion!" "Most of these just need their paths fixed, but other failures will be reported."
	sleep 3
	
	declare -a failedList
	failures=0
	fixedFailures=0
	for song in "${failedSongs[@]}"
	do
		failedList+=("$(determinePath "$song")")
		((failures++))
	done
	
	for songFile in "${failedList[@]}"
	do
		if [[ "$songFile" == *ERROR:* ]]; then
			continue # Just in case something got through
		fi
		
		currentFile="$(outputFilename "$songFile")"
		# If anyone ever asks why I love functions, I will show them this. 
		# The function right here is the reason I love programming (or scripting, to be more specific)
		convertSong "$songFile" "$currentFile"
		if fileTest "$currentFile" # Only really reports the error... Better logging this way
		then
			((fixedFailures++))
		fi
	done
}

### Main Script

processArgs "$@"
#testImport # This line is used for debugging. You can also use the secret --test-import option to do this
checkRequirements "ffmpeg" "dos2unix" #"libmp3lame0" #"moreutils"
if [[ -z $overwrite ]]; then 
	if [[ -z $ffmpegOptions ]]; then
		ffmpegOptions="-y"
	else
		ffmpegOptions="$ffmpegOptions""-y"
	fi
fi

# Error checking for outputFolder should only trigger if it is not a valid directory
if [[ ! -d "$outputFolder" ]]; then
	debug "l2" "ERROR: $outputFolder is not a directory!"
	getUserAnswer "n" "Would you like to attempt to make this directory? (Be careful!)"
	case $? in
		0)
		debug "Attempting to create directory..."
		mkdir "$outputFolder"
		folderTest "$outputFolder"
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
#outputFailures # More debugging

if [[ "${#failedSongs[@]}" -ne 0 ]]; then
	debug "l2" "Attempting to convert failed songs..."
	processFailures
fi

announce "Script has completed successfully!" "Please consult log for any file that could not be converted!"
debug "Total songs: $total, converted songs: $songsConverted, failed songs: $failures, fixed songs: $fixedFailures"

#EOF