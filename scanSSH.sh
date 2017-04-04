#!/bin/bash
start=40
end=60
network="10.100.41."

for addr in $(seq "$start" "$end");
do
	ip="$network""$addr"
	printf "INFO: Scanning %s for SSH availability\n" "$ip"
	nc -z -w5 "$ip" 22 # SSH port
	if [[ "$?" -eq 0 ]]; then
		printf "INFO: %s is SSH-able!\n" "$ip"
	else
		printf "INFO: %s is not available!\n" "$ip"
	fi
done

#EOF
