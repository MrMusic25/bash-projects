#!/bin/bash
#
# gmmPlaylistConverter.sh - Quick script I wrote to translate a .txt from GMM to M3U
# Based on the Python script I wrote, which will be uploaded later
#
# Changes:
# v1.0.0
# - Ready for release!
# - Working, minus ~10% of songs, which will be fixed via the Python script used to download the Google playlists
# - Reasoning: sed is hard, python is easy
#
# v0.4.1
# - Undid the stream editing since it helped with nothing at all... 10% is better than nothing
#
# v0.4.0
# - Copy+paste x5 for official iTunes folders
# - Added output to m3u
# - Finished writing folderCrawler(), since I forgot to do that earlier
# - Added an array of failed songs for easier printing after conversion
# - Added some stream editing to the songs for failures
#
# v0.3.0
# - Added cycleUnnowns(), which checks Compilations and other folders
# - Not done with it, but committing
#
# v0.2.0
# - Updated variables to locals for safety in folderCrawler()
# - Universal delimiter for the same reason
# - Made new function attempt(), which tried entering the directory, and checks for spelling errors
#
# v0.1.1
# - Started doing some work, then got confused... Need to make a tree diagram, brb
#
# v0.1.0
# - Can't believe I forgot to include the base search directory as an argument... smh
# - Added folderCrawler()
# - More work on script as a whole
#
# v0.0.3
# - Can't escape those minor text fixes
#
# v.0.0.2
# - Added -m|--manual-hierarchy and related variables
# - Added -n|--no-compilations and related variables
# - Got rid of more of the script template crap
# - Side note: I love how EVERY time I go to commit, I think of a new ides to quickly add lol
#
# v0.0.1
# - Initial version
# - defaultTemplate -> gmmc.sh prep
#
# TODO:
#
# v1.0.0, 11 May 2017, 00:56 PST

### Variables

longName="gmmPlaylistConverter"
shortName="gmmc" # Was gonna put "gpc", but that might have been confusing lol
hierarchy=3 # Default, for Artist-Album-Title folders. Can be changed if, say, you are searching an unknown depth of folders
compilations=1 # Define whether or not to search in the common iTunes folder "Compilations/"
textFile="NULL" # https://i.redd.it/2u9lbxq9nxpy.jpg
baseDirectory="NULL" # Where to begin searching for songs, by default. Should be the main Music folder
delim='^' # Makes it easier to change the delimiter, if I find unsupported songs

### Functions

if [[ -f commonFunctions.sh ]]; then
	source commonFunctions.sh
elif [[ -f /usr/share/commonFunctions.sh ]]; then
	source /usr/share/commonFunctions.sh
else
	echo "commonFunctions.sh could not be located!"
	
	# Comment/uncomment below depending on if script actually uses common functions
	echo "Script will now exit, please put file in same directory as script, or link to /usr/share!"
	exit 1
fi

function displayHelp() {
read -d '' helpVar <<"endHelp"

gmmPlaylistConverter.sh - Convert a .txt file from GMM to an M3U file for m2u.sh

Usage: ./gmmc [options] <text_file> <music_directory> [output_filename]
If output filename is omitted, script will use the same name as the input

Options:
-h | --help                           : Display this help message and exit
-v | --verbose                        : Prints verbose debug information. MUST be the first argument!
-m | --manual-hierarchy <interger>    : Manually set the number of folders to search for unknown files
-n | --no-compilations                : Turns off automatic searching of the iTunes' Compilations folder on primary search failure

Names in the text file should be formatted like: Artist-Album-Title
This is the usual file hierarchy. Modify the script if yours is different
Each song needs MINIMUM of two pieces of information to be found: title, and either artist or album

endHelp
echo "$helpVar"
}

function processArgs() {
	if [[ $# -lt 1 ]]; then
		debug "l2" "ERROR: No arguments given! Please fix and re-run"
		displayHelp
		exit 1
	fi
	
	while [[ $loopFlag -eq 0 ]]; do
		key="$1"
		
		if [[ -f "$key" ]]; then
			textFile="$key"
			if [[ -z $2 || ! -d "$2" ]]; then
				debug "l2" "FATAL: Incorrect call for script! Please fix and re-run"
				displayHelp
				exit 1
			else
				baseDirectory="$2"
			fi
			
			if [[ ! -z $3 ]]; then
				outputFile="$3" # These should be the last three args	
			fi
			loopFlag=1
			return 0
		fi
			
		case "$key" in
			-h|--help)
			displayHelp
			exit 0
			;;
			-m|--man*) # What a DASHING young MAN!
			if [[ -z $2 ]]; then
				debug "l2" "ERRROR: Incorrect call for $key! No argument given! Please fix and run again!"
				displayHelp
				exit 1
			elif [[ "$2" -ne "$2" ]]; then # Quick way to test if $2 is an interger
				debug "l2" "ERROR: $2 is not an interger! Please fix and re-run!"
				displayHelp
				exit 1
			else
				hierarchy="$2"
				manualHierarchy=1
				debug "INFO: Manual hierarchy is set to $hierarchy"
				shift
			fi
			;;
			-n|--no*)
			debug "INFO: Compilations folder will not be searched!"
			compilations=0
			;;
			*)
			debug "l2" "ERROR: Unknown option given: $key! Please fix and re-run"
			displayHelp
			exit 1
			;;
		esac
		shift
	done
}

# Takes a song in the format of 'Artist-Album-Song Title' as an argument
# Outputs the file to $m3uItems[@], if it can be found
function folderCrawler() {
	local string
	local artist
	local album
	local title # SC2155
	local newString
	local fullPath
	string="$1"
	#fixedString="$(echo "$string" | sed 's/:/_/g; s/&/\\&/g; s/!/\\!/g; s/\//_/g; s/\./\\./g')"
	album="$(echo "$string" | cut -d "$delim" -f2)"
	artist="$(echo "$string" | cut -d "$delim" -f1)"
	title="$(echo "$string" | cut -d "$delim" -f3)"
	debug "l5" "INFO: Attempting to find $title in $album by $artist"
	
	# Make sure the most important piece of information is set
	if [[ -z $title ]]; then
		debug "l2" "ERROR: No title for string $string, cannot complete! Please find file manually!"
		return 1
	fi
	
	# Next, make sure the album is set (2nd most important)
	if [[ -z $album ]]; then
		debug "l2" "WARN: Album is not set for string $string! Attempting to continue..."
	fi
	
	# Now start searching
	PPWD="$(pwd)"
	attempt "$artist"
	if [[ "$?" -ne 0 ]]; then
		debug "l5" "WARN: Artist folder $artist does not exist! Checking compilations and unknown folders..."
		cycleUnknowns "$album" "$title" "$string" # The function handles the rest, including output, so we can safely return now
		cd "$PPWD"
		return $?
	fi
	
	attempt "$album"
	if [[ "$?" -ne 0 ]]; then
		debug "l2" "WARN: Album folder $album could not be found in $artist! Please find and add manually!"
		failedStrings+=("$string")
		cd "$PPWD"
		return 1
	fi
	
	fullPath="$(pwd)"/"$(find . -maxdepth 1 -iname "*$title*" -print0 | cut -d'/' -f2)" # Song will never show up by default
	if [[ -z "$fullPath" || "$fullPath" == "$(pwd)*" ]]; then
		debug "l2" "ERROR: Could not find song from string: $string . Please add manually!"
		failedStrings+=("$string")
		cd "$PPWD"
		return 1
	else
		debug "l5" "INFO: Successfully found song from string $string!"
		m3uItems+=("$fullPath")
		cd "$PPWD"
		return 0
	fi
	# Wew, lad
}

# Input: the name of a folder
# Output: Nothing if successful. If it fails the cd and the secondary spellcheck, it will output an error
# Return value: 0 on success, 1 if folder could not be found
# NOTE: This function WILL change the working directory, be sure to save it beforehand!
function attempt() {
	local tryDir
	tryDir="$1"
	if [[ -d "$tryDir" ]]; then
		debug "l5" "INFO: $tryDir is a valid directory, changing!"
		cd "$tryDir"
		return 0
	fi
	
	# Now attempting spellcheck
	local newDir
	newDir="$(find "$(pwd)" -iname "$tryDir*" -print0)" # Should containt the most likely directory
	if [[ -d "$newDir" ]]; then
		debug "l5" "WARN: Folder $newDir was found through spellcheck, changing now!"
		cd "$newDir"
		return 0
	else
		debug "l2" "ERROR: Could not find a valid folder $tryDir!"
		return 1
	fi
	return 1 # Just in case it made it this far, an error has occurred
}

# Input: Album folder, song title, ful string (in case of failure for reporting
# Output: Debug, only on error. Changes directory if file found
function cycleUnknowns() {
	local album
	local newAlbum
	local title
	local newTitle
	local string
	string="$3"
	album="$1"
	title="$2"
	NPWD="$(pwd)" # This can be safely used, shouldn't have changed if it made it this far
	
	# Time for some ugly, nested if statements!
	if [[ -d Compilations ]]; then
		# Compilations exists. Check for folder
		cd Compilations
		newAlbum="$(find . -maxdepth 1 -iname "$album*" -print0 | cut -d'/' -f2)"
		if [[ ! -z "$newAlbum" ]]; then
			debug "l5" "INFO: Album folder was found in Compilations! Checking for song..."
			cd "$newAlbum"
			newTitle="$(find . -maxdepth 1 -iname "$title*" -print0 | cut -d'/' -f2)"
			if [[ ! -z "$newTitle" ]]; then
				debug "l5" "INFO: Song was found in the Compilations! Adding to array and returning..."
				m3uItems+=("$(pwd)"/"$newTitle")
				cd "$NPWD"
				return 0
			fi
		# Else, continue to other folders
		fi
	fi
	
	if [[ -d Unknown ]]; then
		# Unknown exists. Check for folder
		cd Unknown
		newAlbum="$(find . -maxdepth 1 -iname "$album*" -print0 | cut -d'/' -f2)"
		if [[ ! -z "$newAlbum" ]]; then
			debug "l5" "INFO: Album folder was found in Unknown! Checking for song..."
			cd "$newAlbum"
			newTitle="$(find . -maxdepth 1 -iname "$title*" -print0 | cut -d'/' -f2)"
			if [[ ! -z "$newTitle" ]]; then
				debug "l5" "INFO: Song was found in the Unknown! Adding to array and returning..."
				m3uItems+=("$(pwd)"/"$newTitle")
				cd "$NPWD"
				return 0
			fi
		# Else, continue to other folders
		fi
	fi
	
	if [[ -d "Unknown Artist" ]]; then
		# "Unknown Artist" exists. Check for folder
		cd "Unknown Artist"
		newAlbum="$(find . -maxdepth 1 -iname "$album*" -print0 | cut -d'/' -f2)"
		if [[ ! -z "$newAlbum" ]]; then
			debug "l5" "INFO: Album folder was found in Unknown Artist! Checking for song..."
			cd "$newAlbum"
			newTitle="$(find . -maxdepth 1 -iname "$title*" -print0 | cut -d'/' -f2)"
			if [[ ! -z "$newTitle" ]]; then
				debug "l5" "INFO: Song was found in the Unknown Artist! Adding to array and returning..."
				m3uItems+=("$(pwd)"/"$newTitle")
				cd "$NPWD"
				return 0
			fi
		# Else, continue to other folders
		fi
	fi
	
	if [[ -d Various ]]; then
		# Various exists. Check for folder
		cd Various
		newAlbum="$(find . -maxdepth 1 -iname "$album*" -print0 | cut -d'/' -f2)"
		if [[ ! -z "$newAlbum" ]]; then
			debug "l5" "INFO: Album folder was found in Various! Checking for song..."
			cd "$newAlbum"
			newTitle="$(find . -maxdepth 1 -iname "$title*" -print0 | cut -d'/' -f2)"
			if [[ ! -z "$newTitle" ]]; then
				debug "l5" "INFO: Song was found in the Various! Adding to array and returning..."
				m3uItems+=("$(pwd)"/"$newTitle")
				cd "$NPWD"
				return 0
			fi
		# Else, continue to other folders
		fi
	fi
	
	if [[ -d "Various Artists" ]]; then
		# "Various Artists" exists. Check for folder
		cd "Various Artists"
		newAlbum="$(find . -maxdepth 1 -iname "$album*" -print0 | cut -d'/' -f2)"
		if [[ ! -z "$newAlbum" ]]; then
			debug "l5" "INFO: Album folder was found in Various Artists! Checking for song..."
			cd "$newAlbum"
			newTitle="$(find . -maxdepth 1 -iname "$title*" -print0 | cut -d'/' -f2)"
			if [[ ! -z "$newTitle" ]]; then
				debug "l5" "INFO: Song was found in the Various Artists! Adding to array and returning..."
				m3uItems+=("$(pwd)"/"$newTitle")
				cd "$NPWD"
				return 0
			fi
		# Else, continue to other folders
		fi
	fi
	
	# Above is the template. Copy+paste for any other folder, just edit names
	# e.g. "Unknown", "Unknown Artist", "Various", etc...
	
	# Getting this far, all else has failed. Report, add to array, and move on
	debug "l2" "ERROR: Song $title could not be found from string $string! Please add manually!"
	failedStrings+=("$string")
	return 1
}
### Main Script

processArgs "$@"
# Remember that sweet magic trick your teacher did as you were writing this perp? The one with the card in the girl's test? Yeah....

# Making it this far means file is ready for import, let's begin!
if [[ -z $outputFile ]]; then
	if [[ "$textFile" == *. ]]; then
		outputFile="$textFile" # Text file has no extension
	else
		outputFile="$(echo "$textFile" | rev | cut -d'.' -f1 --complement | rev)"
	fi
fi

# Now the output file is set
importText "$textFile" textContents
OPWD="$(pwd)"
cd "$baseDirectory"
declare -a m3uItems
declare -a failedStrings
for song in "${textContents[@]}";
do
	folderCrawler "$song"
done

# Sanity check
if [[ -z "$m3uItems" ]]; then
	debug "l2" "FATAL: Script dun goof'd. Either it failed or you have bad RAM. Please contact script maintainer. Exiting!"
	exit 1
fi

# Great, let's export the new filenames now
outFile="$outputFile".m3u
touch "$outFile"
for item in "${m3uItems[@]}";
do
	echo "$item" | tee -a "$outFile"
done

if [[ ! -z $failedStrings ]]; then
	pause "Press [Enter] to see a list of failed songs..."
	for itemm in "${failedStrings[@]}"
	do
		printf "String: %s\n" "$itemm"
	done
else
	debug "INFO: No failures while converting $textFile. Miraculous."
fi

cd "$OPWD"
debug "l3" "INFO: Done with script! Please check $outFile!"

#EOF