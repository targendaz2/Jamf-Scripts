#!/bin/bash

# Format: {User ID}-{Make}-{Year}

# Aliases
awk='/usr/bin/awk'
curl='/usr/bin/curl'
cut='/usr/bin/cut'
echo='/bin/echo'
ioreg='/usr/sbin/ioreg'
jamf='/usr/local/bin/jamf'
plistbuddy='/usr/libexec/PlistBuddy'
scutil='/usr/sbin/scutil'
sysctl='/usr/sbin/sysctl'
system_profiler='/usr/sbin/system_profiler'
tr='/usr/bin/tr'

# Editable settings
JAMF_URL="$4"

# Settings that should not be edited
API_USER="$5"
API_PASS="$6"
SERIAL=$($ioreg -c IOPlatformExpertDevice -d 2 | $awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')

# Get the owner's user ID
user_info=$($curl -k ${JAMF_URL}JSSResource/computers/serialnumber/${SERIAL}/subset/location -H "Accept: application/xml" --user "${API_USER}:${API_PASS}")
user_id=$($echo $user_info | $awk -F'<username>|</username>' '{print $2}' | $tr [A-Z] [a-z])


# Get the computer make and year
hardware_info=$($curl -k ${JAMF_URL}JSSResource/computers/serialnumber/${SERIAL}/subset/hardware -H "Accept: application/xml" --user "${API_USER}:${API_PASS}")

make=$($echo $hardware_info | $awk -F'<model_identifier>|</model_identifier>' '{print $2}' | $tr -d '0-9'','' ')

year=$($echo $hardware_info | $awk -F'<model>|</model>' '{print $2}')
year=${year#*(}
year=$($echo "$year" | $tr -dc '0-9')

# Put it all together
name="${user_id}-${make}-${year}"
$echo "Computer name is $name"
$scutil --set ComputerName "$name"
$scutil --set LocalHostName "$name"
$scutil --set HostName "$name"

exit 0
