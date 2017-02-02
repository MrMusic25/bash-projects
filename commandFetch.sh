#!/bin/bash
#
# commandFetch.sh - Check a command server for instructions on what to do (like a botnet, but more localized and less evil)
# Script will check for $hostname based instructions first, then a $general inscturctions list
# If it finds its name in the exclude list of the downloaded script, it will exit
#
# Changes:
# v0.0.2
# - Script is meant to be autonomous; therefore, it will manually download commonFunctions.sh if not detected
# - Same for packageManagerCF.sh
# - Lots TODO
#
# v0.0.1
# - Initial version
#
# TODO:
# - If no cronjob already detected, install a cronjob that runs script in daemon mode every minute
#   ~ Also ask user if they want more than the default alloted time for checking (over metered connections)
# - In daemon mode, no interactive stuff allowed (not that there should be much anways)
# - Look for existing instances of this script before running, in case commands take a long time OR a loop is accidentally created, wasting CPU
#
# v0.0.2, 01 Feb. 2017 23:25 PST

### Variables

hostname="$(cat /etc/hostname)" # Setup by default in every distro I have used
server="$(cat /usr/share/server)" # Default place this script will store server address, which could be a static IP (local) or a hostname/domain (internet)
serverPort=80 # This makes firewall handling easier. 8080 and 443 might be other good options, might be used later in this script
defaultInterval=1 # Number of minutes between checks. Only used when setting up cron

### Functions

if [[ -f commonFunctions.sh ]]; then
	source commonFunctions.sh
elif [[ -f /usr/share/commonFunctions.sh ]]; then
	source /usr/share/commonFunctions.sh
else
	# This script is meant to be autonomous, so if this is not found, it will download it and install it
	echo "ERROR: commonFunctions.sh not found, installing it for you (sudo premission required)!"
	
	wget "https://raw.githubusercontent.com/MrMusic25/linux-pref/master/commonFunctions.sh" # Hard link, should never change
	wget "https://raw.githubusercontent.com/MrMusic25/linux-pref/master/packageManagerCF.sh" # This could always be necessary, so include it!
	chmod +x commonFunctions.sh # Just in case
	chmod +x packageManagerCF.sh
	sudo ln -s "$(pwd)"/commonFunctions.sh /usr/share/commonFunctions.sh
	sudo ln -s "$(pwd)"/packageManagerCF.sh /usr/share/packageManagerCF.sh
	
	source commonFunctions.sh # And continue on with the script... one-time run and setup
fi

function displayHelp() {
# The following will read all text between the words 'helpVar' into the variable $helpVar
# The echo at the end will output it, exactly as shown, to the user
read -d '' helpVar <<"endHelp"

scriptName.sh - A script to perform a function or fulfill a purpose
Be sure to look at all the options below

Usage: ./scriptName.sh [options] <required_argument> <also_required> [optional_argument]

Options:
-h | --help                         : Display this help message and exit
-o | --option                       : Option with an alias (default)
--output-only                       : Option with no shotrened name
-i | --include <file1> [file2] ...  : Option including possibly more than one argument
-a | --assume <[Y]es or [N]o>       : Option that supports full or shortened argument names
-v | --verbose                      : Prints verbose debug information. MUST be the first argument!

Put definitions, examples, and expected outcome here

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