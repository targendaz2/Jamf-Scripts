#!/bin/bash

# Aliases
awk='/usr/bin/awk'
cat='/bin/cat'
curl='/usr/bin/curl'
echo='/bin/echo'
fold='/usr/bin/fold'
head='/usr/bin/head'
ioreg='/usr/sbin/ioreg'
jamf='/usr/local/bin/jamf'
pwpolicy='/usr/bin/pwpolicy'
sysadminctl='/usr/sbin/sysadminctl'
tr='/usr/bin/tr'

# settings
JAMF_URL="$4"
API_USER="$5"
API_PASS="$6"
TEMP_PASS="$($cat /dev/urandom | $tr -dc 'a-zA-Z0-9' | $fold -w 32 | $head -n 1)"
SERIAL=$($ioreg -c IOPlatformExpertDevice -d 2 | $awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}')

# Get the computer owner's info
user_info=$($curl -k ${JAMF_URL}JSSResource/computers/serialnumber/${SERIAL}/subset/location -H "Accept: application/xml" --user "${API_USER}:${API_PASS}")
username=$($echo $user_info | $awk -F'<username>|</username>' '{print $2}' | $tr [A-Z] [a-z])
realname=$($echo $user_info | $awk -F'<realname>|</realname>' '{print $2}')

if [[ "$realname" == '' ]]; then
	realname="$username"
fi


# Create the local account
$jamf createAccount -username "$username" -realname "$realname" -password "$TEMP_PASS" -home "/Users/${username}" -admin


# Reset the local account's password
$sysadminctl -adminUser "$username" -adminPassword "$TEMP_PASS" -secureTokenOn "$username" -password "$TEMP_PASS"
$sysadminctl -adminUser "$username" -adminPassword "$TEMP_PASS" -resetPasswordFor "$username" -newPassword ''
$pwpolicy -u "$username" -setpolicy 'newPasswordRequired=1'

exit 0
