#!/bin/bash
#
# commandFetch.sh - Check a command server for instructions on what to do (like a botnet, but more localized and less evil)
# Script will check for $hostname based instructions first, then a $general inscturctions list
# If it finds its name in the exclude list of the downloaded script, it will exit
#
# Changes:
# v1.0.1
# - Debugging led to minor changes. Script confirmed as working, though!
#
# v1.0.0
# - Ready for full release! Should theoretically work, but untested for now
# - Added code to make sure only one copy of each script can run at the same time (self-script, and all-script)
# - This prevents overwriting of the file, and frees system resources
# - Added checkProcesses() to implement above funcionality
# - Unintentionally, this system allows each user to have their own set of scripts running, thought this really should be root-only
#
# v0.6.0
# - Added determineFile(), the ugly function that works
# - Script checks for files in specific order now, downloading not ready yet
# - Script will exit successfully if no files are available
#
# v0.5.2
# - Changed debug wording
# - Warn user when script not being run as root
#
# v0.5.1
# - Changed the way the processArgs loop works, now has a way to exit gracefully
# - Fixed server port variable names
# - Slightly changed the way netcat is installed. GNU-netcat preferred over openBSD-netcat!
#
# v0.5.0
# - Added package requirements to script
# - Script will now download packageManager.sh if not present
# - Made a check to see if port is open
#
# v0.4.0
# - Added check to see if server is up
# - Added -q option to tell script to quit if ping fails
# - Updated oter functions accordingly
#
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
# v1.0.1, 19 Feb. 2017 00:36 PST

### Variables

hostname="$(cat /etc/hostname)" # Setup by default in every distro I have used
server="$(cat /usr/share/server)" # Default place this script will store server address, which could be a static IP (local) or a hostname/domain (internet)
serverPort=80 # This makes firewall handling easier. 8080 and 443 might be other good options, might be used later in this script
defaultInterval=1 # Number of minutes between checks. Only used when setting up cron
selfScript="$HOME"/selfScript # These two lines are used to make sure only one copy of each script can run at the same time
allScript="$HOME"/allScript
quitPing=0 # Tells computer whether to quit if ping is unsuccessful
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
	wget "https://raw.githubusercontent.com/MrMusic25/linux-pref/master/packageManager.sh" # Adding checkRequirements made this necessary for full autonomy
	chmod +x commonFunctions.sh # Just in case
	chmod +x packageManagerCF.sh
	chmod +x packageManager.sh
	sudo ln -s "$(pwd)"/commonFunctions.sh /usr/share/commonFunctions.sh
	sudo ln -s "$(pwd)"/packageManagerCF.sh /usr/share/packageManagerCF.sh
	sudo ln -s "$(pwd)"/packageManagerCF.sh /usr/bin/pm
	
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
-h | --help                : Display this help message and exit
-d | --daemon              : Stops interactive functions from running, make sure it is included in cronjobs!
-q | --quit-ping           : Script will quit if ping fails. Default is to attempt to continue.
-s | --server <address>    : Specify the IP address/host/domain name to check with. Will NOT update the default address!
-p | --port <port_num>     : Specify the port to use with wget
-h | --hostname <name>     : Changes the hostname to check against the server with
-i | --install [user]      : Install script as cronjob, with option to do so as current user (default is root)
-v | --verbose             : Enable verbose mode. Note: MUST be the first argument!

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
	
	argCount=1
	args="$#"
	while [[ $loopFlag -eq 0 ]]; do
		key="$1"
		
		case "$key" in
			-h|--help)
			displayHelp
			exit 0
			;;
			-q|--quit-ping)
			debug "INFO: Script is set to quit if ping fails"
			quitPing=1
			;;
			-s|--server)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No server address given with $key! Please fix and re-run!"
				exit 1
			fi
			server="$2"
			debug "INFO: Server temporarily set to: $server"
			shift
			((argCount++))
			;;
			-p|--port)
			if [[ -z $2 ]]; then
				debug "l2" "ERROR: No port number given with $key! Please fix and re-run!"
				exit 1
			elif [[ ! "$2" -eq "$2" ]]; then # If $2 is not an integer, report and exit
				debug "l2" "ERROR: Argument $2 is not a valid integer or port number! Please fix and re-run!"
				exit 1
			fi
			serverPort="$2"
			debug "INFO: Port temporarily set to $serverPort"
			shift
			((argCount++))
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
			((argCount++))
			;;
			-i|--install)
			if [[ "$2" == "user" ]]; then
				installScript "user"
				shift
				((argCount++))
			else
				installScript
			fi
			;;
			*)
			debug "l2" "ERROR: Unknown option $key given! Please fix and re-run!"
			exit 1
			;;
		esac
		shift
		
		((argCount++))
		if [[ $argCount -ge $args ]]; then
			loopFlag=1
		fi
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

function determineFile() {
	# self.sh takes precedence over all.sh
	# Order to check: HostName.sh -> hostname.sh -> HOSTNAME.sh -> all.sh -> ALL.sh -> All.sh
	
	# This isn't going to be pretty, but it should be efficient enough
	if [[ -z "$(curl -I --silent "$serverURL"/"$hostname".sh | grep 404)" ]]; then
		downloadFile="$hostname".sh
		scriptMode="self"
		return 0
	elif [[ -z "$(curl -I --silent "$serverURL"/"${hostname,,}".sh | grep 404)" ]]; then
		downloadFile="${hostname,,}".sh # tolower()
		scriptMode="self"
		return 0
	elif [[ -z "$(curl -I --silent "$serverURL"/"${hostname^^}".sh | grep 404)" ]]; then
		downloadFile="${hostname^^}".sh # toupper()
		scriptMode="self"
		return 0
	elif [[ -z "$(curl -I --silent "$serverURL"/all.sh | grep 404)" ]]; then
		downloadFile=all.sh
		scriptMode="all"
		return 0
	elif [[ -z "$(curl -I --silent "$serverURL"/ALL.sh | grep 404)" ]]; then
		downloadFile=ALL.sh
		scriptMode="all"
		return 0
	elif [[ -z "$(curl -I --silent "$serverURL"/All.sh | grep 404)" ]]; then
		downloadFile=All.sh
		scriptMode="all"
		return 0
	else
		downloadFile="NULL"
		return 1
	fi
}

function checkProcesses() {
	# Check to see if processes are even running, quit if so
	case "$scriptMode" in
		self)
		debug "INFO: Script is set to self mode! Checking for existing process..."
		if [[ -e "$selfScript" ]]; then
			debug "l2" "FATAL: Script is running in self mode, but an existing script is already running! Exiting for now..."
			exit 0 # Success because it's part of the script's function
		else
			debug "INFO: No self scripts running! Locking the self-script and prepping to run!"
			touch "$selfScript"
		fi
		;;
		all)
		debug "INFO: Script is set to all mode! Checking for existing process..."
		if [[ -e "$allScript" ]]; then
			debug "l2" "FATAL: Script is running in all mode, but an existing script is already running! Exiting for now..."
			exit 0
		else
			debug "INFO: No all scripts running! Locking the all-script and prepping to run!"
			touch "$allScript"
		fi
		;;
		*)
		debug "l2" "ERROR: Unknown scriptMode: $scriptMode ! Please diagnose and retry!"
		exit 1
		;;
	esac
}

### Main Script

# Link the script to /usr/bin if not already there
if [[ ! -e /usr/bin/commandFetch ]]; then
	debug "l3" "Script is not linked to /usr/bin, please give root permissions to complete!"
	sudo ln -s "$(pwd)"/"$0" /usr/bin/commandFetch
fi

checkRequirements "nc/gnu-netcat" "nc/netcat" "wget" # Having it twice may seem counter-intuitive, but I found not all versions use the same version. GNU preferred, so it is first
processArgs "$@" # Check to see if server given here before exiting

# Warn the user that this should be run as root, not as user; continue anyways, but give a warning
if [[ $EUID -ne 0 ]]; then
	debug "l2" "WARN: It is highly recommended to run this script as root!"
	sleep 3
fi

if [[ -z "$server" && ! -e "/usr/share/server" ]]; then
	debug "FATAL: No server given, and no default server found at /usr/share/server! Please fix and re-run!"
	# Tried to let debug handle this, but there was too much info to give
	announce "Server is not set and is not given as an option!" "Please set the default server in /usr/share/server" "Or, re-run the script with the -s <server> option!"
	sleep 3
	exit 1
fi

# Test to see if server is up
ping -c 5 "$server"
value="$?"
case $value in
	0)
	debug "Server is responsive, continuing"
	;;
	*)
	if [[ "$quitPing" -eq 0 ]]; then
		debug "l2" "WARN: Server unresponsive, ICMP may be blocked or server is down. Attempting to continue... (Ping value: $value)"
	else
		debug "l2" "WARN: Server unresponsive, quitting by user decision! (Ping value: $value)"
		exit 1
	fi
	;;
esac

# Better way - test to see if port is open; added req for netcat
nc -z -w5 "$server" "$serverPort"
case $? in
	0)
	debug "INFO: Server port is open, moving on!"
	;;
	*)
	debug "l2" "ERROR: Port $serverPort on $server is not open, or server is unresponsive. Quitting script for now!"
	exit 1
	;;
esac

# Server is up and available if it makes it this far
serverURL="http://$server:$serverPort"
determineFile
if [[ $? -ne 0 ]]; then
	debug "WARN: Server is up, but no commands are currently available! Quitting for now..."
	exit 0 # Successful because there won't be commands everytime
fi
checkProcesses # This will exit script if any other errors come up

# Making it this far means server is up, server has a script ready for computer, and script is not already being run
scriptFile="$HOME"/"$downloadFile" # Don't want to cause issues with cron or systemd or anything, so base this in the home folder
curl --silent "$serverURL"/"$downloadFile" > "$scriptFile" # This way, we don't have to worry about existing files
chmod +x "$scriptFile"

# Ladies and gentlemen, boys and girls, it's the moment you've all been waiting for!
# *drum roll*
# TAH-DAH!!!!!!
eval "$scriptFile"

# ..... Had to put those comments, because this felt like the most uneventful thing to happen to a 400+ line project lol
# ANYWAYS....... xD

# Time to cleanup and report what happened
rvalue="$?"
if [[ "$rvalue" -ne 0 ]]; then
	debug "l2" "WARN: Script completed with a non-zero exit code! Exit code: $rvalue"
else
	debug "l2" "WARN: Script completed successfully!"
fi

# Remove process lock and 
case "$scriptMode" in
	self)
	rm "$selfScript"
	;;
	all)
	rm "$allScript"
	;;
esac
rm "$scriptFile"

announce "Done with script!"

#EOF