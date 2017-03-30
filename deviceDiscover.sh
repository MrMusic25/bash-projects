#!/bin/bash
#
# deviceDiscover.sh - Script that will scan a network and report newly discovered devices
# Use case: You plug in a new device, and can immediately know it's IP address
#
# Changes:
# v0.0.1
# - Initial version
#
# TODO:
#
# v0.0.1, 30 March 2017, 15:01 PST

### Variables

# These variables are used for logging
# longName is preferred, if it is missing it will use shortName. If both are missing, uses the basename of the script
longName="deviceDiscover"
shortName="dDis"

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

deviceDiscover.sh - A script to discover new devices on a network
Used to find a new device on the network, so you can use its IP address (Raspberry Pi)
Run this script first, then plugin device! Only works on /24 networks for now.

Usage: ./deviceDiscover.sh [options] [network] [range]
Network can be IP address or end in '.0'. Defaults to eth0 if blank.
Range must be formatted as '#-#', if included

Options:
-h | --help                         : Display this help message and exit
-v | --verbose                      : Prints verbose debug information. MUST be the first argument!

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
			--output-only) # Long, unaliased names should always go first so they do not create errors. Try to avoid similar names!
			outputOnly="true"
			;;
			-h|--help)
			displayHelp
			exit 0
			;;
			-o|--option)
			option=1
			;;
			-i|--include)
			# Be careful with these, always check for file validity before moving on
			# Doing it this way makes it you can add as many files as you want, and then continuing
			until [[ "$2" == -* ]]; do # Keep looping until an option (starting with a - ) is found
				if [[ -f "$2" ]]; then
					# This adds the filename to the array includeFiles - make code later to perform an action on each file
					includeFiles+=("$2")
					shift
				else
					# displayHelp and exit if the file could not be found, safety measure
					debug "l2" "ERROR: Argument $2 is not a valid file or argument!"
					displayHelp
					exit 1
				fi
			done
			;;
			-a|--assume)
			if [[ "$2" == "Y" || "$2" == "y" || "$2" == "Yes" || "$2" == "yes" ]]; then
				assume="true"
				shift
			elif [[ "$2" == "N" || "$2" == "n" || "$2" == "No" || "$2" == "no" ]]; then
				assume="false" # If this is the default value, you can delete this line, used for example purposes
				shift
			else
				# Invalid value given with -a, report and exit!
				debug "l2" "ERROR: Invalid option $2 given with $key! Please fix and re-run"
				displayHelp
				exit 1
			fi
			;;
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

#EOF