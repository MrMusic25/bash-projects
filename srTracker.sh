#!/bin/bash
#
# Purpose: A script to help me learn stats about my Overwatch SR ranking. Can be used for other numerical ranking systems, as well
#
# Usage: ./srTracker.sh [text_file]
#
# v1.0, 14 Apr. 2018, 09:47 PST

source /usr/share/commonFunctions.sh

### Vars

longName="srTracker"
shortName="srt"
trackFile="sr.txt" # Location of the SR file, usually in present dir
timeBetweenUpdates=3 # Number of games between notifying user of SR stats

### Functions

function displayStats() {
    if [[ ! -z $1 ]]; then
        printf "%s\n" "$1" # Prints given message before continuing
    fi
    
    # Math
    local sessionDiff=0
    local overallDiff=0
    local sessionGames=0
    [[ -z $lastUpdate ]] && lastUpdate="$currentSR"
    local updateDiff=0
    ((sessionDiff=-1*(beginSR-currentSR)))
    ((overallDiff=-1*(start-currentSR)))
    ((updateDiff=-1*(lastUpdate-currentSR)))
    ((sessionGames=numGames-beginGames))
    
    # Words
    if [[ "$sessionDiff" -lt 0 ]]; then
        sessionWord="down"
        ((sessionDiff*=-1))
    elif [[ "$sessionDiff" -eq 0 ]]; then
        sessionWord="at"
    else
        sessionWord="up"
    fi
    
    if [[ "$overallDiff" -lt 0 ]]; then
        overallWord="down"
        ((overallDiff*=-1))
    elif [[ "$overallDiff" -eq 0 ]]; then
        overallWord="at"
    else
        overallWord="up"
    fi
    
    if [[ "$updateDiff" -lt 0 ]]; then
        updateWord="down"
        ((updateDiff*=-1))
    elif [[ "$updateDiff" -eq 0 ]]; then
        updateWord="at"
    else
        updateWord="up"
    fi
    
    # Print it all in one big printf statement
    printf "Stats: You are %s %s SR this session (%s %s SR since last update), %s %s SR overall; %s games tonight.\n" "$sessionWord" "$sessionDiff" "$updateWord" "$updateDiff" "$overallWord" "$overallDiff" "$sessionGames"
}

### Main

# Use $1 as trackFile, if present
if [[ -f "$1" ]]; then
    debug "l2" "INFO: Using supplied file $1 as SR file!"
    trackFile="$1"
elif [[ "$1" != " " || "$1" != "" ]]; then
    debug "l2" "WARN: File not found at input $1!"
    getUserAnswer "Would you like to use $1 as the SR file?"
    if [[ $? -eq 0 ]]; then
        debug "WARN: Using $1 as SR file per user request"
        trackFile="$1"
    else
        debug "l2" "FATAL: SR file not found! Exiting..."
        exit 1
    fi
fi

# Make sure file exists
if [[ ! -e "$trackFile" ]]; then
    debug "l2" "ERROR: trackFile not found, initializing!"
    if ! touch "$trackFile"; then
        debug "l2" "FATAL: User does not have permission to write to srTracker directory! Please fix and re-run!"
        exit 1
    fi
    read -p "Please enter current SR: " start
    echo "$start" > "$trackFile"
else
    start="$(head -n1 $trackFile)"
fi

# Initialize all numbers
numGames=0 # Divisor for average
totalDelta=0 # Add all the deltas together, divide it by numGames later
currentSR="$start"
while read line
do
    # Prevents error by re-importing initial value
    if [[ -z $flag ]]; then
        flag=1
        continue
    fi
    
    # Sanity check
    if [[ "$line" -ne "$line" ]]; then # Checks to see if line is a number
        debug "l2" "ERROR: line $line is not a number! Continuing anyways, press CTRL+C to stop..."
        continue
    fi
    
    ((numGames++))
    ((totalDelta+=-1*(currentSR-line))) # Needs to be negative, because math
    currentSR="$line"
done<"$trackFile"

beginSR="$currentSR" # Start of SR for the play session
beginGames="$numGames" # Tells you total number of games in play session
sessionDelta="$totalDelta" # Also need the beginning delta for session delta
updateCount=1 # Number of entries since last update
#debug "l2" "INFO: Starting the night with SR $beginSR"
displayStats "Beginning the session with the following stats!"

# And now, endless loop
while [[ -z $exitFlag ]];
do
    read -p "Enter the SR from your last match, or enter quit to exit: " newSR
    case $newSR in
        q*)
        exitFlag=1
        ;;
        *)
        if [[ "$newSR" -ne "$newSR" ]]; then
            debug "l2" "ERROR: Invalid input detected - $newSR!"
        else
            ((totalDelta+=-1*(currentSR-newSR)))
            ((numGames++))
            currentSR="$newSR"
        fi
        echo "$newSR" >> "$trackFile"
        ;;
    esac
    if [[ "$updateCount" -ge "$timeBetweenUpdates" ]]; then
        displayStats
        updateCount=1
    else
        ((updateCount++))
    fi
done

debug "INFO: Done playing for this session, printing final stats and exiting!"
displayStats "Final stats for this session!"
exit 0

#EOF
