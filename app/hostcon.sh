#!/bin/bash
# Major revision of host-slave connection on *nix/x86 platforms
# Based on positional parameters (http://linuxcommand.org/wss0130.php)

interactive=
primehci=
flash=
reinstall=
host="linux"
error=()

# all command options in CAPS deal with hci devices and shouldn't need to be
# passed except in hci error cases.
while [ "$1" != "" ]; do
	case $1 in
		-h | --host )			shift
								host=$1
								;;
		-u | --uid )			shift
								uid=$1
								;;
		-d | --dev )			shift
								devassgn=$1
								;;
		-s | --sketchpath )		shift
								skpath=$1
								;;
		-e | --errorkey )		shift
								errorkey=$1
								;;
		-r | --reinstall )		reinstall="reinstall"
								;;
		-f | --flush )			flush="flush"
								;;
		-i | --interactive )	interactive="interactive"
								;;
		-p | --pairbind )		pairbind="pairbind"
								;;
		-P | --primehci )		primehci="primehci"
								;;
		-S | --switch  )		switch="switch"
								;;
		-A | --allup )			allup="allup"
								;;

	esac
	shift
done

# the following conditionals are specific to the interactive
# hostcon prompt call
if [ "$interactive" = "1" ]; then
	echo -n "Enter host platform [$host] > "
	read response
	if [ -n "$response" ]; then
		host=$response
	fi

	echo -n "Enter robot uid > "
	read response
	if [ -n "$response" ]; then
		uid=$response
	fi

	echo -n "Enter dev device assignment > "
	read response
	if [ -n "$response" ]; then
		devassgn=$response
	fi

	echo -n "Enter sketch filepath > "
	read response
	if [ -n "$response" ]; then
		skpath=$response
	fi

	echo -n "Would you like to pair and bind host to client? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		pairbind="pairbind"
		echo -n "Will pair and bind $host to $uid at $devassgn."
		echo ""
	fi

	echo -n "Would you like to reinstall $uid firmware? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		reinstall="reinstall"
		echo -n "Will upload default firmware to $uid."
		echo ""
	fi

	echo -n "Would you like to flush device? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		flush="flush"
		echo -n "Will flush $uid from $devassgn."
		echo ""
	fi

	echo -n "Would you like to prime a HCI device? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		primehci="primehci"
		echo -n "Will prime a HCI device."
		echo ""
	fi

	echo -n "Would you like to switch out current HCI device? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		switch="switch"
		echo -n "Will switch out current HCI device."
		echo ""
	fi

	echo "DEBUG-only feature!"
	echo -n "Would you like to pull up ALL HCI devices? (y/n) >"
	read response
	if [ "$response" = "y" ]; then
		allup="allup"
		echo -n "Will pull up all HCI devices."
		echo ""
	fi
fi

echo "host=$host:uid=$uid"
echo "flush=$flush:dev=$devassgn"
echo "reinstall=$reinstall:skpath=$skpath"
echo "interactive=$interactive"
echo "primehci=$primehci:switch=$switch:allup=$allup"

function optexecute {
	echo "starting prompted execution scripts"
	while [ "$1" != "" ]; do
		case $1 in
			"linux" ) linuxscripts $reinstall $flush $primehci $pairbind $switch $allup;;
			"windows" ) windowsscripts $reinstall $flush $primehci $pairbind $switch $allup;;
			"darwin" ) darwinscripts $reinstall $flush $primehci $pairbind $switch $allup;;
		esac
		shift
	done
	echo "checking for any runtime errors"
	errorcatch
}

function linuxhciallup {
	# pull all available interfaces up.

	echo "pulling up all HCI devices"
	hcicnfvar=($(hciconfig | grep -o "hci."))
	hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
	hcitllist=($(echo "${hcitlvar#$'\n'}"))
	# http://bash.cyberciti.biz/guide/Perform_arithmetic_operations
	hcitltotal=$((${#hcitllist[@]}/2))

	tl=$(echo "$hcitltotal")
	cn=$(echo "${#hcicnfvar[@]}")

	# first check if the number of UP HCIs are less than available HCIs.
	if [ "$tl" -lt "$cn" ] && [ "$tl" -ne 0 ] && [ "$cn" -ne 0 ]; then
		# determine the number of available HCIs that aren't up.
		hcinumdiff=$((${#hcicnfvar[@]}-$hcitltotal))
		echo "$hcinumdiff local host device(s) is/are down"
		# for each HCI device that's up compare it to the list of HCI devices
		# that are available, if an available HCI device doesn't match then
		# pull it up.
		for (( h=0; h<"$tl"; h++ )); do
			if [ "$(($h%2))" = 0 ]; then
				for (( n=0; n<"$cn"; n++ )); do
					if [ "${hcitllist[$h]}" != "${hcicnfvar[$n]}" ]; then
						hciconfig -a "${hcicnfvar[$n]}" reset
						exstat=$?
						if [ "$exstat" = "0" ]; then 
							echo "${hcicnfvar[$n]} reset on host"
							hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
							hcitllist=($(echo "${hcitlvar#$'\n'}"))
							hcitltotal=$((${#hcitllist[@]}/2))
							# global error variable used to determine internal
							# states of bash functions. It is looped over when
							# the bash subprocess call is complete.
							error+=(0)
						else
							# hciconfig reset failed
							error+=(1)
						fi
					fi
				done
			fi
		done
	elif [ "$tl" -eq 0 ] && [ "$cn" -gt 0 ]; then
		for (( n=0; n<"$cn"; n++)); do
			hciconfig -a "${hcicnfvar[$n]}" reset
			exstat=$?
			if [ "$exstat" = "0" ]; then 
				echo "${hcicnfvar[$n]} reset on host"
				hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
				hcitllist=($(echo "${hcitlvar#$'\n'}"))
				hcitltotal=$((${#hcitllist[@]}/2))
				# global error variable used to determine internal
				# states of bash functions. It is looped over when
				# the bash subprocess call is complete.
				error+=(0)
			else
				# hciconfig reset failed
				error+=(2)
			fi
		done
	fi
	if [ "$cn" -ne 0 ]; then
		if [ "$tl" -eq "$cn" ]; then
			echo "all interfaces are already up"
		fi
	else
		# no host HCI interfaces available, no critical error
		error+=(3)
	fi

	# if [ "$error" = 1 ]; then exit 1; fi
}

function linuxhciswitch {
	# iteratively switch to any alternative HCI interface on each call.

	echo "Switching over host HCI devices"
	hcicnfvar=($(hciconfig | grep -o "hci."))
	hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
	hcitllist=($(echo "${hcitlvar#$'\n'}"))
	hcitltotal=$((${#hcitllist[@]}/2))

	# these variables shouldn't be required. initially done because integer and 
	# string comparisons are different in bash.
	tl=$(echo "$hcitltotal")
	cn=$(echo "${#hcicnfvar[@]}")

	# check if there are multiple HCI interfaces to switch over. Otherwise exit.
	if [ "$cn" -gt 1 ]; then
		# ensure there's only one HCI interface up. Otherwise run linuxhciprimer.
		if [ "$tl" -eq 1 ]; then
			hcinumdiff=$(($cn-$tl))
			echo "current bluetooth host set to ${hcitllist[1]}"
			echo "$hcinumdiff local host device(s) can be switched over"
			# currpathnum stores the digit value of the running HCI interface.
			currpathnum=$(echo "${hcitllist[0]}" | grep -o '[0-9]$') #cpn
			# start a loop over each available HCI interface to count over for
			# the possible values that can be assigned as current HCI interface.
			posspathnum=0
			for (( c=0; c<"$cn"; c++ )); do
				# posspathnum stores the digit value of the in-loop HCI interface.
				posspathnum=$(echo "${hcicnfvar[$c]}" | grep -o '[0-9]$') #ppn
				# hcimax is the max index value of the available HCI interfaces.
				hcimax=$(($(echo "${#hcicnfvar[@]}")-1))
				# ppn=cpn; then just assign to next available interface.
				if [ "$posspathnum" -eq "$currpathnum" ]; then
					# ensure that ppn is always less than hcimax
					if [ "$posspathnum" -lt "$hcimax" ]; then
						posspathnum=$(($posspathnum+1))
						hciconfig -a "hci$currpathnum" down
						# additional $? variable, prexstat variable used to
						# ensure this tiered process completes as expected.
						prexstat=$?
						hciconfig -a "hci$posspathnum" reset
						exstat=$?
						if [ "$exstat" = "0" ] && [ "$prexstat" = 0 ]; then 
							echo "switched from hci$currpathnum to hci$posspathnum"
							hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
							hcitllist=($(echo "${hcitlvar#$'\n'}"))
							hcitltotal=$((${#hcitllist[@]}/2))
							error+=(0)
						else
							# HCI switch failed
							error+=(4)
						fi
					fi
				fi
				# ppn<cpn (hcimax<cpn>hcimax); we need to ensure that cpn isn't
				# he highest HCI value, if not increment to a value higher. If
				# higher, force an interface assignment to hci0, the next loop
				# will then start from ppn=cpn.
				if [ "$posspathnum" -lt "$currpathnum" ]; then
					if [ "$currpathnum" -ne "$hcimax" ]; then
						while [ "$posspathnum" -le "$currpathnum" ]; do
							# increment ppn until one value higher than cpn.
							posspathnum+=1
						done
						hciconfig -a "hci$currpathnum" down
						prexstat=$?
						hciconfig -a "hci$posspathnum" reset
						exstat=$?
						if [ "$exstat" = "0" ] && [ "$prexstat" = 0 ]; then 
							echo "switched from hci$currpathnum to hci$posspathnum"
							hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
							hcitllist=($(echo "${hcitlvar#$'\n'}"))
							hcitltotal=$((${#hcitllist[@]}/2))
							error+=(0)
						else
							# HCI switch failed
							error+=(5)
						fi
					else
						# forcing interface assignment to hci0
						posspathnum=0
						hciconfig -a "hci$currpathnum" down
						prexstat=$?
						hciconfig -a "hci$posspathnum" reset
						exstat=$?
						if [ "$exstat" = "0" ] && [ "$prexstat" = 0 ]; then 
							echo "switched from hci$currpathnum to hci$posspathnum"
							hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
							hcitllist=($(echo "${hcitlvar#$'\n'}"))
							hcitltotal=$((${#hcitllist[@]}/2))
							error+=(0)
						else
							# HCI switch failed
							error+=(6)
						fi
					fi
				fi
			done
		else
			# many interfaces are up, will fix to only one running interface.
			linuxhciprimer
		fi
	elif [ "$cn" = 1 ]; then
		# only one host HCI interface found
		error+=(7)
	else
		# no host HCI interfaces found, non-critical
		error+=(8)
	fi
}

function linuxhciprimer {
	# this function ensures that only one HCI device is used per session.

	echo "Priming HCI device on host"
	hcicnfvar=($(hciconfig | grep -o "hci."))
	hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
	hcitllist=($(echo "${hcitlvar#$'\n'}"))
	# http://bash.cyberciti.biz/guide/Perform_arithmetic_operations
	hcitltotal=$((${#hcitllist[@]}/2))

	# these variables shouldn't be required. initially done because integer and 
	# string comparisons are different in bash.
	tl=$(echo "$hcitltotal")
	cn=$(echo "${#hcicnfvar[@]}")

	echo "${hcitltotal} HCI interfaces are up"
	# if only 1 HCI device is up, then print it and set to no error state (0).
	if [ "$tl" -eq 1 ]; then
		# we have to do this loop to separate hci values from their BD Addresses
		# in the hcitllist list variable.
		for (( i=0; i<"$tl"; i++ )); do 
			if [ "$(($i%2))" = 0 ]; then
				hcitldev=$(echo "${hcitllist[$i]}")
				hcitluid=$(echo "${hcitllist[$(($i+1))]}")
				echo "$hcitldev=$hcitluid"
				error+=(0)
			fi
		done
	elif [ "$tl" -eq 0 ]; then
		# no HCI interface are up. Check if any are available in next conditional
		error+=(23)
		if [ "$cn" -eq 0 ]; then
			# no HCI interface are available. Force exit
			error+=(24)
			errorcatch
		fi
	else
		# pull down ALL available interfaces.
		for (( h=0; h<"$tl"; h++ )); do
			if [ "$(($h%2))" = 0 ]; then
				hciconfig -a "${hcitllist[$h]}" down
				exstat=$?
				if [ "$exstat" = "0" ]; then 
					echo "${hcicnfvar[$n]} reset on host"
					hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
					hcitllist=($(echo "${hcitlvar#$'\n'}"))
					hcitltotal=$((${#hcitllist[@]}/2))
					error+=(0)
				else
					# HCI interface pull down failed
					error+=(9)
				fi
			fi
		done
		# pull up hci0 after pulling down all available interfaces.
		posspathnum=0
		hciconfig -a "hci$posspathnum" reset
		exstat=$?
		if [ "$exstat" = "0" ]; then 
			echo "hci$posspathnum reset on host"
			hcitlvar=$(hcitool dev | while read line; do echo "${line#Devices:}"; done)
			hcitllist=($(echo "${hcitlvar#$'\n'}"))
			hcitltotal=$((${#hcitllist[@]}/2))
			error+=(0)
		else
			# HCI interface pull up failed
			error+=(10)
		fi
	fi
}

function linuxflush {
	# begin flushing process
	echo "Starting flush on linux host"
	echo "Starting release process:"
	# We first determine if the passed device dev assignment
	# exists in the rfcomm table.
	devfind=$(rfcomm | grep -o "$devassgn")
	# We then check if the passed uid exists in the same
	# rfcomm table to determine if it's already bound to either the
	# assigned device path or another one.
	uidfind=$(rfcomm | grep "$uid")
	# matchuid is used to match the passed uid to the assigned device path
	# but only if the latter hasn't already been assigned.
	matchuid=$(echo "$uidfind" | grep -o "rfcomm.")

	if [ -z "$devfind" ]; then
		echo "$devassgn not previously attached"
	else
		if [ "$devfind" = "$matchuid" ]; then
			rfcomm release "/dev/$devassgn"
			exstat=$?
			if [ "$exstat" = "0" ]; then 
				echo "$uid unbound from $host host"
			else
				# Rfcomm release failed
				error+=(11)
			fi
		else
			# Rfcomm device path found ($matchuid) doesn't match the app assigned value ($devfind)
			error+=(12)
		fi
	fi

	echo "Starting unpair process:"
	# determine macid of host bluetooth device to unpair client
	hciuid=$(hciconfig | grep -o ..:..:..:..:..:..)
	if [ -z "$hciuid" ]; then
		# no host HCI interface found, critical: force script exit
		error+=(13)
		errorcatch
	else
		# pair to the passed macid variable.
		if [ -f /var/lib/bluetooth/$hciuid/linkkeys ]; then
			keychck=$(cat /var/lib/bluetooth/$hciuid/linkkeys | grep -o $uid)
			if [ -z "$keychck" ]; then
				error+=(14)
			else
				bluez-test-device remove $uid
				exstat=$?
				# http://stackoverflow.com/questions/748445/shell-status-codes-in-make
				if [ "$exstat" = "0" ]; then 
					echo "Unpairing" $uid "successful"
				else
					error+=(15)
				fi
			fi
			# exit 0
			error+=(0)
		fi
	fi
}

function linuxreinstall {
	echo "Starting firmware reinstall of serial devices"
	export ARDUINO_DIR=/usr/share/arduino
	export BOARD=uno
	# determine if device dev paths have been assigned to any USB serial devices
	# devs contains the device dev paths that matched
	# devnos contains the number of devices that matched
	devpaths=($(find /sys -name "ttyACM*" | grep devices))
	devnum=${#devpaths[@]}
	# if USB device devs have been found proceed to reinstall i.e. devnum>0
	if [ "$devnum" != 0 ]; then
		for dev in ${devpaths[@]}; do
			# use udevadm tool to determine if dev paths have Arduino in their metadata
			ardcheck=$(udevadm info -a -p ${dev#./sys} | grep Arduino)
			# if there are arduino associated dev paths attempt to upload the firmware
			if [ ! -z "$ardcheck" ]; then
				target=/dev/$(echo $dev | grep -o ttyACM.)
				echo "Dev path:"$dev" Dev num:"$devnum" Target:"$target
				export SERIALDEV=$target
				export ARDUINO_PORT=$target
				export ARDUINO_LIBS="Servo Wire Firmata"
				make -C $skpath upload
				exstat=$?
				# $? is a shell status code that returns the previous commands exit code
				if [ "$exstat" = "0" ]; then 
					# firmware upload was successful
					error+=(0)
				else
					# firmware upload was unsuccessful
					error+=(16)
				fi
			else
				# no Arduinos found attached to USB ports
				error+=(28)
			fi
		done
	else
		# no USB devices attached to host
		error+=(27)
	fi
}

function linuxpandb {
	echo "Pairing and Binding"
	# begin pairing and binding process
	# restart systemd dbus and bluetooth services as a fail safe check
	# NOTE: restarting the dbus will break a Linux Guest OS running on a VM.
	# Turn on only if you're sure you won't be running your fork on a VM.
	# service dbus restart
	service bluetooth restart
	echo "Checking connection status of" $uid "to" $host "host"
	# bluetooth ping(ONCE) the bluetooth client to confirm it's up
	if l2ping "$uid" -c 1; then
		echo "Pinging" $uid "to ensure device is up"
		# devfind conditional checks if submitted UID is already registered on rfcomm,
		# if not it pairs to and binds the passed macid variable
		devfind=$(rfcomm | grep $uid)
		hciuid=$(hciconfig | grep -o ..:..:..:..:..:..)
		if [ -z "$devfind" ]; then
			echo "Starting pairing process:"
			# pair to the passed macid variable.
			if [ ! -z $hciuid ]; then
				echo "Checking if $uid previously paired to $hciuid"
				if [ -f /var/lib/bluetooth/$hciuid/linkkeys ]; then
					keychck=$(cat /var/lib/bluetooth/$hciuid/linkkeys | grep -o $uid)
					if [ -z "$keychck" ]; then
						echo 1234 | bluez-simple-agent $hciuid $uid
						exstat=$?
						# http://stackoverflow.com/questions/748445/shell-status-codes-in-make
						if [ "$exstat" = "0" ]; then 
							echo $uid "paired"
							error+=(0)
						else
							# pairing to $uid failed
							error+=(17)
						fi
					else
						echo $uid "previously paired"
					fi
				fi
			else
				# no host HCI interfaces available
				error+=(25)
			fi
			# rfchck conditional checks if the passed dev device has already been
			# bound. It releases and binds the passed macid if it has.
			rfchck=$(rfcomm | grep $devassgn)
			if [ -z "$rfchck" ]; then
				echo "Starting binding process:"
				# bind the passed macid to the assigned rfcomm port on channel 1
				rfcomm bind "/dev/"$devassgn $uid 1
				exstat=$?
				# http://stackoverflow.com/questions/748445/shell-status-codes-in-make
				if [ "$exstat" = "0" ]; then 
					echo $uid "bound to /dev/$devassgn"
					error+=(0)
				else
					# binding to $uid to /dev/$devassgn failed
					error+=(18)
				fi
			else
				prebound=$(echo $rfchck | grep -o "..:..:..:..:..:..")
				# /dev/$devassgn already bound to $prebound
				error+=(19)
			fi
		else
			# client has already been bound to
			# devassgnchck determines if the passed devassgn value
			devassgnchck=$(echo $devfind | grep -o "rfcomm.")
			if [ "$devassgnchck" = "$devassgn" ]; then
				echo $(hcitool name $uid) "already bound to /dev/$devassgn"
				echo "Performing pairing status validation"
				if [ ! -z $hciuid ]; then
					if [ -f /var/lib/bluetooth/$hciuid/linkkeys ]; then
						keychck=$(cat /var/lib/bluetooth/$hciuid/linkkeys | grep -o $uid)
						if [ -z "$keychck" ]; then
							echo 1234 | bluez-simple-agent $hcinum $uid
							exstat=$?
							# http://stackoverflow.com/questions/748445/shell-status-codes-in-make
							if [ "$exstat" = "0" ]; then 
								echo "$uid paired"
								error+=(0)
							else
								# bluetooth pairing to $uid failed
								error+=(20)
							fi
						else
							echo "$uid previously paired"
						fi
					fi
				else
					# no host HCI interfaces available
					error+=(26)
				fi
			else
				# $uid already assigned to $devassgnchck, won't force assignment to $devassgn
				error+=(21)
			fi
		fi
		# Pairing and Binding process went through flawlessly
		rfcomm
		error+=(0)
	else
		# bluetooth ping failed to find passed macid.
		error+=(22)
	fi
}

function errorcatch {
	errorcount=0
	if [ "$host" = "linux" ]; then
		for e in ${error[@]}; do
			case $e in
				"0" ) echo "operation successful";;
				"1" ) echo "error 1: error while resetting ${hci[$n]}";;
				"2" ) echo "error 2: error while resetting ${hci[$n]}";;
				"3" ) echo "error 3: no host HCI interfaces available";;
				"4" ) echo "error 4: error while switching from hci$currpathnum to hci$posspathnum";;
				"5" ) echo "error 5: error while switching from hci$currpathnum to hci$posspathnum";;
				"6" ) echo "error 6: error while switching from hci$currpathnum to hci$posspathnum";;
				"7" ) echo "error 7: one HCI interface available, HCI switch cannot be done";;
				"8" ) echo "error 8: no host HCI interfaces available";;
				"9" ) echo "error 9: error pulling down ${hcicnfvar[$c]} interface";;
				"10" ) echo "error 10: error while pulling up hci$posspathnum";;
				"11" ) echo "error 11: rfcomm release of /dev/$devassgn failed";;
				"12" ) echo "error 12: Device path assigned to $matchuid match the app assigned value $devfind";;
				"13" ) echo "error 13: no HCI interfaces available, forced script exit";;
				"14" ) echo "error 14: $uid not previously paired to";;
				"15" ) echo "error 15: unpairing $uid not successful";;
				"16" ) echo "error 16: $(basename $skpath) firmware upload was unsuccessful";;
				"17" ) echo "error 17: bluetooth pairing to $uid failed";;
				"18" ) echo "error 18: binding to $uid to /dev/$devassgn failed";;
				"19" ) echo "error 19: /dev/$devassgn already bound to $prebound";;
				"20" ) echo "error 20: bluetooth pairing to $uid failed";;
				"21" ) echo "error 21: $uid already assigned to $devassgnchck";;
				"22" ) echo "error 22: bluetooth pinging $uid failed ";;
				"23" ) echo "error 23: no HCI interfaces are up";;
				"24" ) echo "error 24: no host HCI interfaces available, forced script exit";;
				"25" ) echo "error 25: no host HCI interfaces available";;
				"26" ) echo "error 26: no host HCI interfaces available";;
				"27" ) echo "error 27: no USB devices attached to host";;
				"28" ) echo "error 28: no Arduinos attached to host";;
			esac
			if [ "$e" != 0 ]; then
				errorcount=$(($errorcount+1))
			else
				errorcount=$(($errorcount+0))
			fi
		done
		if [ "$errorcount" -gt 0 ]; then
			echo "$errorcount errors occured"
			homedir=$(dirname $(pwd))
			if [ ! -f $homedir/data/error.log ]; then
				touch $homedir/data/error.log
			fi
			echo -e "{\"error\": {\"key\":\""$errorkey"\", " >> $homedir/data/error.log
				for err in "${error[@]}"; do
					jsonend=$errorcount
					for (( j="$jsonend"; j>=1; j-- )); do
						if [ "$j" != 1 ]; then
							echo -e "\"code\": \""$err"\"," >> $homedir/data/error.log
						else
							echo -e "\"code\": \""$err"\"}}" >> $homedir/data/error.log
						fi
					done
				done
			exit $errorcount
		else
			echo "no errors occured"
			exit 0
		fi
	fi
}

function windowsscripts {
	echo "Setting up host-client connection for $uid on $uid host"
	echo ""
	sleep 3
}

function darwinscripts {
	echo "Setting up host-client connection for $uid on $uid host"
	echo ""
	sleep 3
}

function linuxscripts {
	echo "starting linux script execution"
	while [ "$1" != "" ]; do
		case $1 in
			"reinstall" ) linuxreinstall;;
			"flush" ) linuxflush;;
			"pairbind" ) linuxpandb;;
			"allup" ) linuxhciallup;;
			"primehci" ) linuxhciprimer;;
			"switch" ) linuxhciswitch;;
		esac
		shift
	done
}

optexecute $host