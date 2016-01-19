#!/bin/bash
echo "Trying to mount peripheral devices"
mount -t devtmpfs none /dev
udevd &
udevadm trigger
service dbus restart
service bluetooth restart

echo "Testing working directory and starting run.py"
flask/bin/python tests.py

flask/bin/python db_start.py
flask/bin/python run.py

echo "Copying makefiles to sketch directories"
# http://askubuntu.com/questions/300744/copy-the-content-file-to-all-subdirectory-in-a-directory-using-terminal
for d in sketches/*/; do
	cp /usr/share/arduino/Arduino.mk "$d"Makefile
done

hcinum=$(hciconfig | grep -o hci.)
# conditional to check that the hci device is not down
# NOTE: -z is an empty/unset variable check that returns true if variable isn't set
# alternatively, -n checks if a variable is non-empty/set and returns True if it is
if [ ! -z "$hcinum" ];then
	echo "Found $hcinum"
	echo "Will now reset $hcinum"
	echo "$(hciconfig)"
	hciconfig -a $hcinum reset
	echo "$(hciconfig)"
else
	echo "No HCI device found"
fi