#!/bin/bash
#
# gmmPlaylistConverter.sh - Quick script I wrote to translate a .txt from GMM to M3U
# Based on the Python script I wrote, which will be uploaded later
#
# Changes:
# v0.0.1
# - Initial version
# - defaultTemplate -> gmmc.sh prep
#
# TODO:
#
# v0.0.1, 07 Apr. 2017, 09:24 PST

### Variables

# These variables are used for logging
# longName is preferred, if it is missing it will use shortName. If both are missing, uses the basename of the script
longName="gmmPlaylistConverter"
shortName="gmmc" # Was gonna put "gpc", but that might have been confusing lol

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
# The following will read all text between the words 'helpVar' into the variable $helpVar
# The echo at the end will output it, exactly as shown, to the user
read -d '' helpVar <<"endHelp"

gmmPlaylistConverter.sh - Convert a .txt file from GMM to an M3U file for m2u.sh

Usage: ./gmmc [options] <text_file> [output_filename]
If output filename is omitted, script will use the same name as the input

Options:
-h | --help                         : Display this help message and exit
-v | --verbose                      : Prints verbose debug information. MUST be the first argument!

Names in the text file should be formatted like: Artist-Album-Title
This is the usual file heirarchy. Modify the script if yours is different

endHelp
echo "$helpVar"
}

function processArgs() {
	# displayHelp and exit if there is less than the required number of arguments
	# Remember to change this as your requirements change!
	if [[ $# -lt 1 ]]; then
		debug "l2" "ERROR: No arguments given! Please fix and re-run"
		displayHelp
		exit 1
	fi
	
	# This is an example of how most of my argument processors look
	# Psuedo-code: until condition is met, change values based on input; shift variable, then repeat
	while [[ $loopFlag -eq 0 ]]; do
		key="$1"
		
		# In this example, if $key and $2 are a file and a directory, then processing arguments can end. Otherwise it will loop forever
		# This is also where you would include code for optional 3rd argument, otherwise it will never be processed
		if [[ -f "$key" && -d "$2" ]]; then
			inputFile="$key"
			outputDir="$2"
			
			if [[ -f "$3" ]]; then
				tmpDir="$3"
			fi
			loopFlag=1 # This will kill the loop, and the function. A 'return' statement would also work here.
		fi
			
		case "$key" in
			-h|--help)
			displayHelp
			exit 0
			*)
			# Anything here is undocumented or uncoded. Up to user whether or not to continue, but it is recommended to exit here if triggered
			debug "l2" "ERROR: Unknown option given: $key! Please fix and re-run"
			displayHelp
			exit 1
			;;
		esac
		shift
	done
}

### Main Script

processArgs "$@" # Make sure to include the "$@" at the end of the call, otherwise function will not work
# Remember that sweet magic trick your teacher did as you were writing this perp? The one with the card in the girl's test? Yeah....

#EOF