#!/bin/bash
#
# Script used to test functions and ideas before putting it into production

source /usr/share/commonFunctions.sh

[[ -z $1 ]] && echo "Please give a playlist file as an argument!" && exit 1
m3uFile="$1"
declare -a filePaths
fixed=0
total=0

# Import file
while read -r line
do
	[[ "$line" == \#* ]] && continue # Skip the line if it starts with a '#'
	filePaths+=("$line")
	((total++))
done < "${m3uFile}"

for path in "${filePaths[@]}"
do
	printf "Path: %s\n" "$path"
	
	printf "      Exists?: "
	if [[ -e "$path" ]]; then
		printf "True\n"
	else
		printf "False\n"
	fi
	
	printf "      Is a file?: "
	if [[ -f "$path" ]]; then
		printf "True\n"
	else
		printf "False\n"
	fi
	
	folder="$(echo "$path" | rev | cut -d'/' -f1 --complement | rev)"
	printf "      Containing folder: %s\n" "$folder"
	printf "      Folder exists?: "
	if [[ -d "$folder" ]]; then
		printf "True\n\n"
	else
		printf "False\n\n"
	fi
done

echo "Now attempting to fix files!"
pause

for paths in "${filePaths[@]}"
do
	# Now, try to 'find' these files
	artistFolder="$(echo "$paths" | rev | cut -d'/' -f3 | rev)"
	albumFolder="$(echo "$paths" | rev | cut -d'/' -f2 | rev)"
	fileName="$(echo "$paths" | rev | cut -d'/' -f1 | rev)"
	container="$(echo "$paths" | rev | cut -d'/' -f1-3 --complement | rev)"
	extension="$(echo "$fileName" | rev | cut -d'.' -f1 | rev)" # the rev's in this one make sure periods in filename don't get cut
	fileName="$(echo "$fileName" | rev | cut -d'.' -f1 --complement | rev)"
	
	printf "Path: %s\n" "$paths"
	
	# First, check container
	printf "      Container: %s\n" "$container"
	printf "         Valid directory?: "
	if [[ -d "$container" ]]; then
		printf "True\n"
	else
		printf "False\n"
		printf "      Problem is (somehow) in the containing folder!\n\n"
		continue
	fi
		
	# Artist folder
	testPath="$container"/"$artistFolder"
	printf "      Artist folder: %s\n" "$testPath"
	printf "         Valid directory?: "
	if [[ -d "$testPath" ]]; then
		printf "True\n"
	else
		printf "False\n"
		printf "Problem found in artist folder!\n"
		
		# Now see if running through 'title' makes it work
		artistFolder="$(echo -e "$artistFolder" | sed -r 's/\<./\U&/g')"
		testPath="$container"/"$artistFolder"
		printf "         Path with title fix: %s\n" "$testPath"
		printf "         Does fix solve problem?: "
		if [[ -d "$testPath" ]]; then
			printf "True\n" # Running script proved no artist titles were to blame, no need for more testing
		else
			printf "False\n"
			printf "      Unknown issue has arisen!\n\n"
			continue
		fi
		#continue
	fi
	
	# Album folder
	testPath="$container"/"$artistFolder"/"$albumFolder"
	printf "      Album folder: %s\n" "$testPath"
	printf "         Valid directory?: "
	if [[ -d "$testPath" ]]; then
		printf "True\n"
	else
		printf "False\n"
		printf "      Problem is in the album folder!\n"
		
		# Now see if running through 'title' makes it work
		albumFolder="$(echo -e "$albumFolder" | sed -r 's/\<./\U&/g')"
		testPath="$container"/"$artistFolder"/"$albumFolder"
		printf "         Path with title fix: %s\n" "$testPath"
		printf "         Does fix solve problem?: "
		if [[ -d "$testPath" ]]; then
			printf "True\n"
			testPath="$testPath"/"$fileName"."$extension"
			printf "      New full path: %s\n" "$testPath"
			printf "         Album fix worked?: "
			if [[ -f "$testPath" ]]; then
				printf "True\n"
				printf "      Issue was with album folder!\n"
				((fixed++))
				continue
			else
				printf "False\n" # Move on, fix title
			fi
		else
			printf "False\n"
			printf "      Fixing album created issues!\n"
			# See if 'find' can find folder
			testPath="$(find "$container/$artistFolder" -iname "$(echo "$albumFolder" | cut -d' ' -f1)*" -print0)"
			printf "      Find command found: %s\n" "$testPath"
			printf "         Valid directory?: "
			if [[ -d "$testPath" ]]; then
				printf "True\n"
				albumFolder="$(echo "$testPath" | rev | cut -d'/' -f1 | rev)"
				printf "      Album is now: %s\n" "$albumFolder"
				printf "      New path valid?: "
				testPath="$container"/"$artistFolder"/"$albumFolder"/"$fileName"."$extension"
				if [[ -f "$testPath" ]]; then
					printf "True\n"
					printf "      Problem solved with find!\n\n"
					((fixed++))
					continue
				else
					printf "False\n" # Still an issue with filename, directory is good though so move on
				fi
			else
				printf "False\n"
				printf "      Directory is not in parent!\n\n"
				continue
			fi
		fi
		#continue
	fi
	
	# If you made it this far, only option left is bad filename
	fileName="$(echo -e "$fileName" | sed -r 's/\<./\U&/g')"
	printf "      Filename must be the issue!\n"
	printf "      Fixed filename: %s\n" "$fileName"
	testPath="$container"/"$artistFolder"/"$albumFolder"/"$fileName"."$extension"
	printf "      Fixed full path: %s\n" "$testPath"
	printf "         Did the fixes work? "
	if [[ -f "$testPath" ]]; then
		printf "True\n\n"
		((fixed++))
		continue
	else
		printf "False\n"
		printf "      Fixing the case did not work!\n"
		testPath="$(find "$container/$artistFolder/$albumFolder" -iname "$(echo "$fileName" | cut -d' ' -f1)*" -print0)"
		printf "      Find command found: %s\n" "$testPath"
		printf "         Valid file?: "
		if [[ -f "$testPath" ]]; then
			printf "True\n"
			printf "      Find found the correct file!\n\n"
			((fixed++))
		else
			printf "False\n"
			printf "      File is nowhere to be found!\n\n"
		fi
	fi
done

printf "Songs fixed: %s/%s\n\n" "$fixed" "$total"
#EOF