#!/bin/bash
#
# networkTester.sh - A script to see if there are any internet connection issues on a given interface
#
# Usage: ./networkTester.sh <interface>
#
# Script will run throughthe OSI layers to see where the issue may be. 
# If no interface is given, user will be asked to choose from a list.
#
# Changes:
# v1.0.0
# - Finished version, 2 days later
#
# v0.0.1
# - Initial version
#
# v1.0.0, 14 Aug. 2016 16:37 PST

### Variables

interface="NULL" # Default on most computers
ifCount=1 # Total number of interfaces
ifIP="NULL"

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

function whichInterface() {
	# If an argument is given, assume it is an interface and check
	if [[ ! -z $1 ]]; then
		# If interface does not exist, warn user and continue with script. Else, set $interface and return
		if [[ -z $( ifconfig "$1" 2>/dev/null ) ]]; then
			debug "User tried to use an interface that does not exist! $1"
			echo "WARN: $1 is not a valid interface!"
		else
			export interface="$1"
			return
		fi
	fi
	
	# List interfaces, the ask user which they woudld like to use for this test
	until [[ ! -z $( ifconfig "$interface" 2>/dev/null ) ]]; do
		announce "Please choose the interface you would like to use!" "Enter the interface name, not the number!"
		ifMax=$( ls /sys/class/net | wc -l )
		debug "There were $ifMax interfaces found on this computer."
		
		interfaces="$( ls /sys/class/net )"
		until [[ "$ifCount" -gt "$ifMax" ]]; do
			subString="$( echo $interfaces | cut -d ' ' -f "$ifCount" )" # Ignore SC2086
			printf " %s.    %s\n\n" "$ifCount" "$subString"
			((ifCount++))
		done

		read -p " Please enter your choice: " interface
	done
}

function testOSI() {
	# Layer 1 - Physical
	if ! ifconfig "$1" | grep -q RUNNING; then
		debug "Issue found in layer 1 - Physical layer. Is cable plugged in, or connected to a wireless network?"
		return 1
	fi
	
	# Layer 2 - Data Link
	ping -c 5 "127.0.0.1" &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "Issue found in layer 2 - Data Link layer. Cable is connected, but is it the right kind of cable?"
		return 2
	fi
	
	# Layer 3 - Network
	ping -c 5 "$2" &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "Issue found in layer 3 - Network layer. Computer has IP address, but cannot ping itself. This shouldn't happen, you are really special."
		return 3
	fi
	
	# Layer 4 - Transport Layer
	gateway=$( netstat -nr | grep "$interface" | grep G | cut -d ' ' -f 10 )
	ping -c 5 "$gateway" &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "Issue found in layer 4 - Transport layer. You received an IP address, but are unable to reach the gateway. Is your router on/plugged in?"
		return 4
	fi
	
	# Layer 5 - Session Layer
	ping -c 5 "8.8.8.8" &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "Issue found in layer 5 - Session layer. You can reach the gateway, but you cannot connect to the internet. Your ISP may be having issues."
		return 5
	fi
	
	# Layer 6 - Presentation Layer
	ping -c 5 "google.com" &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "An issue was detected on layer 6 - Presentation layer. Diagnosing further."
		dnsServer="$( nm-tool | grep DNS | cut -d ' ' -f 18 | sed '2d' )"
		
		# Testing if DNS server is reachable
		ping -c 5 "$dnsServer" &>/dev/null
		if [[ "$?" -ne 0 ]]; then
			debug "DNS server is not reachable. Trying secondary DNS"
			dnsServer2="$( nm-tool | grep DNS | cut -d ' ' -f 18 | sed '1d' )"
			ping -c 5 "$dnsServer2" &>/dev/null
			if [[ "$?" -ne 0 ]]; then
				debug "Both DNS servers are down. Either change them from DHCP or manually, or wait for them to come back up!"
				return 6
			else
				debug "The primary DNS server is non-responsive, but the secondary is not. Should be working, checking just in case..."
				if [[ -z $( dig @"$dnsServer2" +noall +answer google.com ) ]]; then
					debug "Primary server is down, but secondary is reachable but not responding to DNS queries. Change DNS servers via DHCP or manually, or wait for them to come back up."
					#return 9
				fi
			fi
		else
			debug "Primary DNS server is up, checking if it is responding to requests."
			if [[ -z $( dig @"$dnsServer" +noall +answer google.com ) ]]; then
				debug "Primary DNS is up, but not responding to requests! Verifying secondary server."
				dnsServer2="$( nm-tool | grep DNS | cut -d ' ' -f 18 | sed '1d' )"
				ping -c 5 "$dnsServer2" &>/dev/null
				if [[ "$?" -ne 0 ]]; then
					debug "Both DNS servers are down. Either change them from DHCP or manually, or wait for them to come back up!"
					return 6
				else
					debug "The primary DNS server is non-responsive, but the secondary is not. Should be working, checking just in case..."
					if [[ -z $( dig @"$dnsServer2" +noall +answer google.com ) ]]; then
						debug "Primary server is down, but secondary is reachable but not responding to DNS queries. Change DNS servers via DHCP or manually, or wait for them to come back up."
						#return 9
					fi
				fi
			else
				debug "Primary DNS server is up and responding to requests! Moving on..."
			fi
		fi
	fi
	
	# Layer 7 - Application Layer
	wget -O /dev/null www.google.com &>/dev/null
	if [[ "$?" -ne 0 ]]; then
		debug "Issue found in Layer 7 - Application layer. You can connect to the internet, but cannot download anything. Reboot router or modem, or wait for ISP to resolve issue."
		return 7
	fi
	
	# No issues found if you made it that far
	debug "No issues found connecting to internet! Contact your local I.T representative if you need additional help!"
	return 0
}

### Main Script

# Checks to see if user has ping and ifconfig privilege, runs as root if not
if [[ -z $( which ifconfig 2>/dev/null ) ]]; then
	debug "ifconfig not present or user does not have enough rights, exiting..."
	#announce "ifconfig could not be found!" "Please re-run as root!"
	checkPrivilege "ask"
	exit
fi

whichInterface "$@"

# Gets IP address of selected interface
ifIP="$( ifconfig "$interface" | grep -oP "\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b" | cut -d $'\n' -f 1 )"

announce "Now detecting any network errors!" "Note: this may take a couple minutes depending on network condtions."

testOSI "$interface" "$ifIP"

case $? in
	0) # Everything is working
	announce "No network errors were found!" "If you are still having issues, please contact your local I.T guy!"
	exit 0
	;;
	1) # Layer 1 - Physical Layer
	announce "Network problems found on Layer 1 - Physical layer!" "Please make sure cable is plugged in, or that you are connected to wireless network!"
	exit 1
	;;
	2) # Layer 2 - Data Link Layer
	announce "Network problems found on Layer 2 - Data Link layer!" "Interface is up, but the connection is not stable." "Reboot the switch or router you are plugged into to fix it."
	exit 2
	;;
	3) # Layer 3 - Network Layer
	announce "Network problems found on Layer 3 - Network layer!" "You cannot ping your own computer, an issue with the network stack." "Reboot your computer to fix the problem!"
	exit 3
	;;
	4) # Layer 4 - Transport Layer
	announce "Network problems found on Layer 4 - Transport layer." "You cannot reach your gateway." "Renew your IP address, or restart your router to fix problem."
	exit 4
	;;
	5) # Layer 5 - Session Layer
	announce "Network problems found on Layer 5 - Session layer." "Your network equipment is up and working, but you cannot connect to the internet."
	announce "This is likely your ISP's fault, wait for the internet to come back up." "You can also try rebooting your router to fix problem."
	exit 5
	;;
	6) # Layer 6 - Presentation Layer
	announce "Network problems found on Layer 6 - Presentation layer." "You can reach the internet, but not your DNS servers." "This will usually resolve itself over time."
	announce "You can also try one or more of the following: " "1. Update the DNS servers in DHCP to 8.8.8.8 and 8.8.4.4" "2. Manually change device's DNS servers" "3. Reboot Router"
	exit 6
	;;
	7) # Layer 7 - Application Layer
	announce "Network problems found on Layer 7 - Application Layer." "You have an internet connection, but cannot download anything."
	announce "This is usually a problem with the router, sometimes the internet itself." "Reboot your router to fix problem, or it will resolve itself over time."
	exit 7
	;;
	*)
	debug "Error: Unknown error code received!"
	exit 10
	;;
esac
#EOF
