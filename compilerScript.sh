#!/bin/bash
#
# compilerScript.sh - A script that will compile a C++ program given and output to current directory
#
# Usage: cs [options] <path_to_Main.cpp> [output_dir]
# See displayHelp for more info
#
# Changes
# v1.1.3
# - Changed all instances of 'ming32' to 'mingw32', watch for errors
#
# v1.1.2
# - Forgot to add error checking for the -c option
# - Easiest way to do above is to check against an array of options, found containsElement() on StackOverflow
# - Despite my beliefs, I switched displayHelp() to use spaces, since tabs can mess up formatting
#
# v1.1.1
# - Added '-static' to mingw options, otherwise it doesn't work on Windows
# - Added -c option to script, adds whatever options the user wants to the compiler
#
# v1.1.0
# - Full mingw support, though some options are not available
#
# v1.0.1
# - Started adding support for mingw32
# - Changed options to use gcc again, turns out g++ is just gcc with special options
#
# v1.0.0
# - Release version ready. NO mingw32 support (yet)
# - Note: While everything refers to gcc, the compiler used is actually g++
#
# v0.0.2
# - Decided options was necessary, added processArgs()
# - Trying out a new method for displayHelp()
#
# v0.0.1
# - Initial version
#
# v1.1.3, 28 Sept. 2016 17:53 PST

### Variables

mainLocation="NULL" # Location of the main cpp file
scriptOptions=("-h" "--help" "-m" "--mode" "-o" "--output-name" "-c" "--compile-option" "-a" "--arch" "-w" "--windows")
outputDir="$(pwd)" # Where the executable will be exported to
gccCompilerOptions="-xc++ -lstdc++ -shared-libgcc -Wall -fexceptions" # Options to compile C++
mingwCompilerOptions="-static" # Options for compiling 
compilerOptions="" # Options added from -c to be used with either compiler
compileMode="debug" # Compile program with debug or release option
executableName="NULL" # Script will automatically change if it hasn't been already
architecture="win32" # 32-bit or 64-bit arch for compiler
compiler="gcc" # gcc, or mingw. More to be added later

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

function containsElement () {
	# Thanks, Patrik on StackOverflow! I improved his version by switching double space to tabs! =)
	local e
	for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
	return 1
}

function processArgs() {
	# If no arguments present, display help and exit
	if [[ $# -eq 0 ]]; then
		export debugFlag=1
		debug "ERROR: No options given, please fix and re-run!"
		displayHelp
		exit 1
	fi
	
	debug "Processing arguments"
	while [[ ! -z $1 ]]; do
		if [[ "$1" == *.cpp ]]; then
			mainLocation="$1"
			if [[ ! -z $2 && -d "$2" ]]; then
				debug "Valid output directory given, using for executable!"
				outputDir="$2"
			fi
			break
		fi
		
		case "$1" in
		-h|--help)
		displayHelp
		exit 0
		;;
		-m|--mode)
		# Check to make sure proper argument given for mode
		if [[ -z $2 || "$2" != "release" || "$2" != "debug" ]]; then
			debug "Not enough options given, or invalid option given with mode!"
			announce "Incorrect usage of $1!" "Please fix and re-run!"
			displayHelp
			exit 1
		fi
		
		# Set mode, shift, and continue
		if [[ "$2" == "release" ]]; then
			compileMode="release"
			shift
		elif [[ "$2" == "debug" ]]; then
			compileMode="debug"
			shift
		else
			debug "Invalid option $2 given with mode!"
			announce "Invalid option $2 given with $1!" "Please fix and re-run"
			displayHelp
			exit 1
		fi
		;;
		-o|--output-name)
		if [[ -z $2 || "$2" == -* || "$2" == --* ]]; then
			debug "Not enough arguments given for $1!"
			announce "Name not given for $1!" "Please fix and re-run!"
			displayHelp
			exit 1
		fi
		
		executableName="$2"
		shift
		;;
		-a|--arch)
		debug "Setting mode to 64-bit!"
		architecture="amd64" # Short and sweet
		;;
		-c|--compile-option)
		# Make sure $2 isn't a script option, then add it
		containsElement "$2" "${scriptOptions[@]}"
		if [[ "$?" -eq 0 ]]; then
			debug "No argument given with -c, found $2 instead"
			announce "ERROR: Invalid argument given with $1 : $2 is a script option!" "Please fix and re-run!"
			exit 1
		fi
		debug "Adding $2 to the compiler options"
		compilerOptions="$compilerOptions"" ""$2"
		shift
		;;
		-w|--windows)
		debug "Outputting Windows version instead of Linux/BSD/OSX!"
		compiler="mingw"
		;;
		*)
		debug "Unknown option given: $1"
		announce "Unknown option given!" "Option: $1" "Please fix and re-run!"
		displayHelp
		exit 1
		;;
		esac
		shift
	done
	
	# Quit if no file was given
	if [[ "$mainLocation" == "NULL" ]]; then
		debug "No .cpp file supplied!"
		announce "No .cpp file was found!" "Please fix and re-run!"
		displayHelp
		exit 1
	fi
}

function displayHelp() {
read -d '' helpVar <<"endHelp"

Usage: cs [options] path_to_Main_file.cpp [output_directory]
Note: If the output directory is missing at runtime, it will output executable to current directory

Options:
   -h | --help                      : Print this help message and exit.
   -m | --mode <debug|release>      : Switches the compiler mode. Debug by default.
   -o | --output-name <string>      : Output name for executable, defaults to main file name, minus the extension.
   -c | --compile-option <string>   : Use as many times as you want. Adds given arguments to compiler. Use quotes!
   -a | --arch                      : Switches from 32-bit to 64-bit architecture for the complier. 
   -w | --windows                   : Outputs a Windows version executable instead of Linux/BSD/OSX version.
	
endHelp
echo "$helpVar"
}

function prepareOptions() {
	# The following variables are, to the best of my knowledge, the commands to be added to gcc
	# NOTE: White-space in front of options is VERY important!!!
	gccReleaseOption=" -O3"
	gccDebugOption=" -g"
	gcc64bitOption=" -m64"
	mingwReleaseOption=" -O3"
	
	case "$compiler" in
	gcc)
	# Set compiler mode to "release"
	if [[ "$compileMode" == "release" ]]; then
		gccCompilerOptions="$gccCompilerOptions""$gccReleaseOption"
	else
		gccCompilerOptions="$gccCompilerOptions""$gccDebugOption"
	fi
	
	# Set 64bit is option says so
	if [[ "$architecture" != "win32" ]]; then
		gccCompilerOptions="$gccCompilerOptions""$gcc64bitOption"
	fi
	
	# Change name to cpp file minus the extension, if it is not set
	if [[ -z $executableName || "$executableName" == "NULL" ]]; then
		executableName="$(echo "$mainLocation" | cut -d'.' -f1)"
	fi
	gccCompilerOptions="$gccCompilerOptions""$compilerOptions"
	;;
	mingw)
	if [[ "$compileMode" == "release" ]]; then
		mingwCompilerOptions="$mingwCompilerOptions""$mingwReleaseOption"
	fi
	
	if [[ -z $executableName || "$executableName" == "NULL" ]]; then
		executableName="$(echo "$mainLocation" | cut -d'.' -f1)"".exe"
	else
		executableName="$executableName"".exe"
	fi
	mingwCompilerOptions="$mingwCompilerOptions""$compilerOptions"
	;;
	*)
	debug "Unknown option received in prepareOptions(): $compiler"
	announce "An error has occurred!"
	exit 1
	;;
	esac
	
	
}

function compileEXE() {
	case $compiler in
	gcc)
	debug "Attempting to run gcc with options: $gccCompilerOptions, file will be at "$outputDir"/"$executableName""
	# NOTE: Do NOT put $compilerOptions in quotes! Breaks everything!
	gcc $gccCompilerOptions "$mainLocation" -o "$outputDir"/"$executableName"
	;;
	mingw)
	debug "Attempting to run mingw with options: $mingwCompilerOptions, file will be at "$outputDir"/"$executableName""
	if [[ "$architecture" == "amd64" ]]; then
		x86_64-w64-mingw32-g++ $mingwCompilerOptions "$mainLocation" -o "$outputDir"/"$executableName"
	else
		i686-w64-mingw32-g++ $mingwCompilerOptions "$mainLocation" -o "$outputDir"/"$executableName"
	fi
	;;
	*)
	debug "Unknown option in compileEXE(): $compiler"
	;;
	esac
}

### Main Script

processArgs "$@" # Function does all the checking
announce "Arguments valid, preparing the rest of the script." "This may take a minute depending on your system."
checkRequirements "gcc" "i686-w64-mingw32-g++/mingw-w64-gcc"
prepareOptions
announce "Now attempting to compile program." "Executable will be output to $outputDir, errors will be below."
compileEXE
announce "Done!"
#EOF