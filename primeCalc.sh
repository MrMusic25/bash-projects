#!/bin/bash
#
# scriptTest.sh - A script to test ideas before implementation

source /usr/share/commonFunctions.sh

### Variables

number=7
primes=3 # 1,3,5 are prime

### Functions

function testPrime() {
	local input="$1"
	((input%2)) && return
	local current=3
	while [[ $current -lt $(( ( input + 1 ) / 2 )) ]];
	do
		((input%current)) && return # Return if current is a factor, meaning not prime
		((current+=2))
	done
	((primes++))
}

function threader() {
	while true;
	do
		checkout wait primeLock
		local newNum=$number
		((number+=2))
		checkout "done" primeLock
		testPrime $newNum
	done
}

### Main

checkRequirements "parallel"
echo "Starting calculations!"
sem -j 4 -- threader

#EOF