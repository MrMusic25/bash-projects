#!/bin/bash
#
# commandFetch.sh - Check a command server for instructions on what to do (like a botnet, but more localized and less evil)
# Script will check for $hostname based instructions first, then a $general inscturctions list
# If it finds its name in the exclude list of the downloaded script, it will exit
#
# Changes:
# v0.3.1
# - Minor text fixes
#
# v0.3.0
# - Got installScript() up and running
# - Coded daemon options
# - Added more debug messages
# - Made a small "workaround" to install cronjob as root... Just run as sudo!
#
# v0.2.0
# - Fixed an error preventing script from running (SC1048)
# - Added checks and warnings when the server is unset
#
# v0.1.0
# - Updated displayHelp and processArgs for this script
# - Added options and descriptions to respective functions
# - Created installScript() function, does nothing so far
#
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
# v0.3.1, 02 Feb. 2017 18:09 PST

### Variables

hostname="$(cat /etc/hostname)" # Setup by default in every distro I have used
server="$(cat /usr/share/server)" # Default place this script will store server address, which could be a static IP (local) or a hostname/domain (internet)
serverPort=80 # This makes firewall handling easier. 8080 and 443 might be other good options, might be used later in this script
defaultInterval=1 # Number of minutes between checks. Only used when setting up cron
daemon=0

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

commandFetch.sh - A script that will check a server for a list of commnads
More or less a botnet, but 99% less sinister!

Usage: ./commandFetch.sh [options]
Meant to be run as-is, but uses modifiers as necessary

Options:
-h | --help                  : Display this help message and exit
-d | --daemon                : Stops interactive functions from running, make sure it is included in cronjobs!
-s | --server <address>      : Specify the IP address/host/domain name to check with. Will NOT update the default address!
-p | --port <port_num>       : Specify the port to use with wget
-h | --hostname <name>       : Changes the hostname to check against the server with
-i | --install [user]        : Install script as cronjob, with option to do so as current user (default is root)
-v | --verbose               : Enable verbose mode. Note: MUST be the first argument!

When script is first run, a cronjob will be automatically added for the user! Be careful when forcing it with -i !
Default is to install as root; therefore, firt time run must be done with sudo or as root! (Same when running -i|--install)
Using the -s option will not update the default server, located at /usr/share/server. Update this manually.
Uses hostname found at /etc/hostname.

endHelp
echo "$helpVar"
}

function processArgs() {
	if [[ "$#" -eq 0 ]]; then
		return # No arguments, then continue
	fi
	
	while [[ $loopFlag -eq 0 ]]; do
		key="$1"
			
		case "$key" in
			-h|--help)
			displayHelp
			exit 0
			;;
			-s|--server)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No server address given with $key! Please fix and re-run!"
				exit 1
			fi
			server="$2"
			debug "INFO: Server temporarily set to: $server"
			shift
			;;
			-p|--port)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No port number given with $key! Please fix and re-run!"
				exit 1
			elif [[ ! "$2" -eq "$2" ]]; then # If $2 is not an integer, report and exit
				debug "l2" "ERROR: Argument $2 is not a valid integer or port number! Please fix and re-run!"
				exit 1
			fi
			port="$2"
			debug "INFO: Port temporarily set to $port"
			shift
			;;
			-d|--daemon)
			debug "Daemon mode enabled"
			daemon=1
			;;
			-h|--hostname)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No hostname given with $key! Please fix and re-run!"
				exit 1
			fi
			hostname="$2" # Puts a lot of trust in the user, same as with server
			debug "INFO: Hostname temporarily set to $hostname"
			shift
			;;
			-i|--install)
			if [[ "$2" == "user" ]]; then
				installScript "user"
				shift
			else
				installScript
			fi
			;;
			*)
			debug "l2" "ERROR: Unknown option $key given! Please fix and re-run!"
			exit 1
			;;
		esac
		shift || loopFlag=1
	done
}

function installScript() {
	# Skip this if daemon mode on
	if [[ $daemon -ne 0 ]]; then
		return
	fi
	
	announce "Beginning first-time setup!" "Root privileges will be required to make links/edit files" "Please enter password at prompts!"
	if [[ ! -e /usr/bin/commandFetch ]]; then
		sudo ln -s "$(pwd)"/"$0" /usr/bin/commandFetch
	fi
	
	if [[ -e /usr/share/server ]]; then
		getUserAnswer "n" "Default server is $(cat /usr/share/server), would you like to change it?"
		case $? in
			0)
			true # Continue to rest of script, which will ask to set a new server
			;;
			1)
			debug "Leaving default server as: $(cat /usr/share/server)"
			return
			;;
			*)
			debug "l2" "ERROR: Unkown return value $? for getUserAnswer! Please try again."
			exit 1
			;;
		esac
	fi
	
	# Setup cronjob, but first ask if user wants to change update interval
	if [[ "$1" == "user" ]]; then
		debug "l3" "INFO: Cronjob will be setup for current user instead of root!"
	elif [[ "$EUID" -ne 0 ]]; then
		# I hate to do it this way, but at the time I couldn't find a way to do this without rewriting everything
		debug "l3" "ERROR: Please run this script as sudo/root to install with privilege!"
		exit 1
	fi
		
	# Again, this is why I love functions
	getUserAnswer "n" "Would you like to change the default time between checks from $defaultInterval minute(s)?" defaultInterval "How many minutes between checks?"
	addCronJob "$defaultInterval" min "/usr/bin/commandFetch -d"
	
	# At this point, either the default server is unset or the user wishes to change it
	read -p "Please type the IP address, hostname, or domain name of the default server: " server
	debug "Changing default server to: $server"
	echo "$server" | sudo tee /usr/share/server > /dev/null
}

### Main Script

# Link the script to /usr/bin if not already there
if [[ ! -e /usr/bin/commandFetch ]]; then
	debug "l3" "Script is not linked to /usr/bin, please give root permissions to complete!"
	sudo ln -s "$(pwd)"/"$0" /usr/bin/commandFetch
fi

processArgs "$@" # Check to see if server given here before exiting

if [[ -z "$server" && ! -f "/usr/share/server" ]]; then
	debug "FATAL: No server given, and no default server found at /usr/share/server! Please fix and re-run!"
	# Tried to let debug handle this, but there was too much info to give
	announce "Server is not set and is not given as an option!" "Please set the default server in /usr/share/server" "Or, re-run the script with the -s <server> option!"
	sleep 3
	exit 1
fi

announce "Done with script!"

#EOF