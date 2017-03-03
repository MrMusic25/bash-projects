#!/bin/bash
#
# scriptTest.sh - A script to test ideas before implementation

source /usr/share/commonFunctions.sh

number=7
primes=3 # 1,3,5 are prime
function testPrime() {
	if [[ $(($1%2)) ]]; then # This will be slow in the beginning, but save time with larger numbers
		# Even number, never going to be prime
		return
	fi
	local current=3
	while [[ $current -lt $(( ( $1 + 1 ) / 2 )) ]];
	do
		[[ $(($1%current)) -eq 0 ]] && return # Return if current is a factor, meaning not prime
		((current+=2))
	done
	((primes++))
}

function threader() {
	while true;
	do
		checkout wait primeLock
		local newNum=$number
		(($number+=2))
		checkout done primeLock
		testPrime $newNum
	done
}

echo "Starting calculations!"
sem -j 4 -- threader
#EOF