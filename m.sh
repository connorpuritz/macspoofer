#!/bin/sh


# Exit code guide:
# 1: command line parsing failed
# 2: script execution failed


#
# Randomly generates and returns a unicast MAC address
#
function generate() {
	# Randomly generate six bytes in hexadecimal
	for i in {1..6}
	do
		local mac+=$(printf '%02x' $((RANDOM%256)))":"
	done
	# Configure two least significant bits of first byte to configure the MAC
	# address as unicast
	local macadd=$(printf '%02x' $(( 0x$(echo "$mac" | cut -d: -f 1) & 254 | 2)))
	# Remove last colon from address
	macadd+=":$(echo "$mac" | cut -d: -f 2-6)"
	echo $macadd
}


#
# Checks whether the argument passed is a valid interface (as in currently in the list of
# hardware ports on the device). If the given interface is valid, it is returned. If it is
# not valid, then the default interface is returned.
# Usage: default_if [interface]
#
function default_if() {
	# Return default
	[ $# -eq 0 ] && echo $(wifi_interface) && return 0

	if_exists=$(networksetup -listallhardwareports | grep Device | sed -n 's/Device: //p' | grep -w $1)
	# Interface not found
	[ -z "$if_exists" ] && echo $(wifi_interface) && return 0
	# Interface found
	echo $1
}


#
# Returns the name of the Wi-Fi interace on the device.
#
function wifi_interface() {
	networksetup -listallhardwareports | sed -n '/Wi-Fi/{n;p;}' | sed -n 's/Device: //p'
}


#
# Changes the MAC address on the specified interface. If an interface is not provided or is
# invalid, it defaults to the Wi-Fi interface. All connections on that port will be killed
# to ensure the MAC address is correctly set.
#
# Usage: spoof [interface]
#
function spoof() {
	local interface=$(default_if $1)
	# Disconnect from wireless interfaces, MAC won't update otherwise
	sudo airport -z
	# Set new MAC address
	local macadd=$(generate_macadd)
	sudo ifconfig $interface ether $macadd
	networksetup -setairportpower $interface off
	echo "New MAC on $interface: $macadd"
}


#
# Returns the permanent and current MAC addresses of specified interface. If the interface
# is not specified or is invalid, it defaults to the Wi-Fi interface.
#
# Usage: report [interface]
#
function report() {
	local interface=$(default_if $1)
	echo "Permanent MAC on $interface:" $(networksetup -getmacaddress $interface | cut -d ' ' -f 3)
	echo "Current MAC on $interface:" $(ifconfig $interface | grep ether | cut -d ' ' -f 2)
}


#
# Prints a help message
#
function help() {
	usage
}


#
# Prints a usage message
#
function usage() {
	echo "Usage: macspoof [-s|--spoof [interface]] [-r|--report [interface]] [-h|--help]"
}


# Constants for optarg
OPT="OPT"
NONOPT="NONOPT"

#
# optarg is used to parse optional arguments for command line options.
# If the value passed is an option, then optarg returns "OPT". If not,
# optarg returns "NONOPT".
#
# Usage: optarg <value>
#
function optarg() {
	# If no argument was passed, print error message and exit
	if [ $# -eq 0 -o -z "$1" ]
	then
		echo "ERROR: No value passed"
		echo "Usage: optarg <value>"
		return 1
	fi

	if [ $(echo "$1" | cut -c 1) == '-' ]
		# value is an opion
		then
			echo $OPT
		# value is not an option
		else
			echo $NONOPT
	fi
}

# Print usage message and exit if no options were passed
[ $# -eq 0 ] && usage && exit 1

default=$(wifi_interface)
while [ $# -gt 0 ]
do
	case $1 in
		-h|--help)
			help
			break;;
		-s|--spoof)
			if [ $# -gt 1 ]
			then
				opt_stat=$(optarg $2)
				if [ $opt_stat == $OPT ]
				then interface=$default && shift 1
				else interface=$2 && shift 2
				fi
			else
				interface=$default && shift 1
			fi
			echo "spoofing $interface";;
		-r|--report)
			if [ $# -gt 1 ]
			then
				opt_stat=$(optarg $2)
				if [ $opt_stat == $OPT ]
				then interface=$default && shift 1
				else interface=$2 && shift 2
				fi
			else
				interface=$default && shift 1
			fi
			report $interface;;
		*)
			printf 'WARNING: Unknown option (ignored): %s\n' "$1" >&2		
			shift 1;;
	esac
done
