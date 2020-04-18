#!/bin/bash

# Much of this was taken from:
# https://github.com/neilmartin83/MacADUK-2019/blob/master/example_provisioning_script.sh

# Script layout taken from:
# https://github.com/jamf/DEPNotify-Starter/blob/master/depNotify.sh


#########################################################################################
# General Information
#########################################################################################
# This script is designed to make implementation of NoMAD Login AD's Notify mechanism
# very easy with limited scripting knowledge. The section below has variables that may be
# modified to customize the end user experience. DO NOT modify things in or below the
# CORE LOGIC area unless major testing and validation is performed.

#########################################################################################
# Registration Settings
#########################################################################################

# The title of the Assigned User text field, as set in the menu.nomad.login.ad plist.
ASSIGNED_USER_TITLE='Assigned User'

# The title of the Device Name text field, as set in the menu.nomad.login.ad plist.
DEVICE_NAME_TITLE='Device Name'

# The title of the Computer Role text field, as set in the menu.nomad.login.ad plist.
DEVICE_ROLE_TITLE='Device Role'

# The domain prefix for the computer role receipt.
ROLE_RECEIPT_PREFIX='org.company.role'


#########################################################################################
# General Appearance
#########################################################################################

# Path to the image to display at the top of the Notify window. Image can be a max of
# 600x100 pixels. Images will be scaled to fit if larger. If this variable is left blank,
# The generic DEPNotify logo will appear.
BANNER_IMAGE_PATH=''

# Title text that will be displayed under the logo while waiting for Jamf policies to
# begin running.
LOADING_TITLE='Please wait a moment...'

# Text that will appear under the progress bar while waiting for Jamf policies to begin
# running.
LOADING_STATUS='Please wait...'

# Title text that will be displayed under the logo while processing submitted
# registration information.
REGISTRATION_TITLE='Processing registration...'

# Title text that will be displayed under the logo while Jamf policies are running.
MAIN_TITLE='Setting things up...'

# Paragraph text that will appear under the title text while Jamf policies are running.
# For a new line, use "\n".
MAIN_TEXT="Please wait while we set this Mac up with the software and settings it needs. This may take 20 to 30 minutes. We'll restart automatically when we're finished, and you'll be able to sign in."

# Text that will appear under the progress bar while pre-onboarding Jamf policies are
# running.
PRE_ONBOARDING_STATUS='Getting things ready...'

# Text that will appear under the progress bar while onboarding Jamf policies are
# running.
ONBOARDING_STATUS='Installing applications and settings...'

# Text that will appear under the progress bar while post-onboarding Jamf policies are
# running.
POST_ONBOARDING_STATUS='Finishing up...'

# Title text that will be displayed under the logo once this script has finished.
COMPLETE_TITLE='All done!'

# Paragraph text that will appear under the title text once this script has finished.
# For a new line, use "\n".
COMPLETE_TEXT="This Mac will restart shortly and you'll be able to log in."

# Text that will appear under the progress bar once this script has finished.
COMPLETE_STATUS='Restarting, please wait...'


#########################################################################################
# Other Settings
#########################################################################################

# Where the log from this script will be stored.
LOG_PATH='/private/tmp/firstrun.log'

# The default time zone the computer should use.
TIME_ZONE='America/New_York'

# Where the user input will be stored temporarily. This should match the
# "UserInputOutputPath" key in the menu.nomad.login.ad plist.
USERIO_PLIST='/var/tmp/userinputoutput.plist'


#########################################################################################
#########################################################################################
# Core Script Logic - Don't Change Without Major Testing
#########################################################################################
#########################################################################################

# Aliases
authchanger='/usr/local/bin/authchanger'
awk='/usr/bin/awk'
caffeinate='/usr/bin/caffeinate'
cp='/bin/cp'
date='/bin/date'
defaults='/usr/bin/defaults'
dscacheutil='/usr/bin/dscacheutil'
echo='/bin/echo'
ioreg='/usr/sbin/ioreg'
jamf='/usr/local/bin/jamf'
rm='/bin/rm'
scutil='/usr/sbin/scutil'
shutdown='/sbin/shutdown'
sleep='/bin/sleep'
softwareupdate='/usr/sbin/softwareupdate'
sw_vers='/usr/bin/sw_vers'
systemsetup='/usr/sbin/systemsetup'
touch='/usr/bin/touch'

# Settings
DEPNOTIFY_LOG='/var/tmp/depnotify.log'

PROVISIONING_DONE_RECEIPT='/private/var/db/receipts/com.depnotify.provisioning.done.bom'
REGISTRATION_DONE_RECEIPT='/private/var/db/receipts/com.depnotify.registration.done.bom'

OS_VERSION=$($sw_vers -productVersion)
OS_BUILD=$($sw_vers -buildVersion)
SERIAL=$($ioreg -rd1 -c IOPlatformExpertDevice | $awk -F'"' '/IOPlatformSerialNumber/{print $4}')

# Function to add date to log entries
log(){
	NOW="$($date +"*%Y-%m-%d %H:%M:%S")"
	$echo "$NOW": "$1"
}

# Logging for troubleshooting
$touch "$LOG_PATH"
exec 2>&1>"$LOG_PATH"

# Preset notify window just in case
$echo "Command: Image: "${BANNER_IMAGE_PATH}"" > "$DEPNOTIFY_LOG"
$echo "Command: MainTitle: ${LOADING_TITLE}"  >> "$DEPNOTIFY_LOG"
$echo "Command: MainText: " >> "$DEPNOTIFY_LOG"
$echo "Status: ${LOADING_STATUS}" >> "$DEPNOTIFY_LOG"

# Let's not go to sleep
log "Disabling sleep..."
$caffeinate -d -i -m -s -u &
caffeinatepid=$!

# Disable Automatic Software Updates during provisioning
log "Disabling automatic software updates..."
$softwareupdate --schedule off

# Set Network Time
log "Configuring Network Time Server..."
$systemsetup -settimezone "$TIME_ZONE"
$systemsetup -setusingnetworktime on

# Wait for the setup assistant to complete before continuing
log "Waiting for Setup Assistant to complete..."
loggedInUser=$($scutil <<< "show State:/Users/ConsoleUser" | $awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
while [[ "$loggedInUser" == "_mbsetupuser" ]]; do
	$sleep 5
	loggedInUser=$($scutil <<< "show State:/Users/ConsoleUser" | $awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
done

# Let's continue
log "Setup Assistant complete, continuing..."

if [[ ! -f "$REGISTRATION_DONE_RECEIPT" ]]; then
    # Wait for the user data to be submitted...
    while [[ ! -f "$USERIO_PLIST" ]]; do
        log "Waiting for user data..."
        $sleep 5
    done

    $echo "Command: MainTitle: ${REGISTRATION_TITLE}"  >> "$DEPNOTIFY_LOG"

    # Process device role
    log 'Processing device role...'
    device_role="$($defaults read "$USERIO_PLIST" "$DEVICE_ROLE_TITLE")"
    $echo "Status: Setting ${DEVICE_ROLE_TITLE} to ${device_role}"  >> "$DEPNOTIFY_LOG"

    role_receipt="/private/var/db/receipts/${ROLE_RECEIPT_PREFIX}.${device_role}.bom"
    $touch "$role_receipt"

    log 'Device role processed'
    $sleep 3

    # Process device name
    log 'Processing device name...'
    device_name="$($defaults read "$USERIO_PLIST" "$DEVICE_NAME_TITLE")"
    $echo "Status: Setting ${DEVICE_NAME_TITLE} to ${device_name}"  >> "$DEPNOTIFY_LOG"

    $scutil --set ComputerName "$device_name"
    $scutil --set LocalHostName "$device_name"
    $scutil --set HostName "$device_name"
    $dscacheutil -flushcache

    log 'Device name processed.'
    $sleep 3

    # Process assigned user
    log 'Processing assigned user'
    assigned_user="$($defaults read "$USERIO_PLIST" "$ASSIGNED_USER_TITLE")"
    $echo "Status: Setting ${ASSIGNED_USER_TITLE} to ${assigned_user}"  >> "$DEPNOTIFY_LOG"

    $jamf recon -endUsername "$assigned_user"

    log 'Assigned user processed'
    $sleep 3

    # Write a registration complete receipt
    log 'Marking registration as complete'
    $touch "$REGISTRATION_DONE_RECEIPT"

    # Clear UserInput mech, just in case of restart
    log 'Clearing UserInput login mech'
    $authchanger -reset -preLogin NoMADLoginAD:Notify
    $killall -HUP NoMADLoginAD
fi


# Carry on with the setup...

# Change title and text...
$echo "Command: Image: "${BANNER_IMAGE_PATH}"" >> "$DEPNOTIFY_LOG"
$echo "Command: MainTitle: "${MAIN_TITLE}""  >> "$DEPNOTIFY_LOG"
$echo "Command: MainText: "${MAIN_TEXT}""  >> "$DEPNOTIFY_LOG"

log "Initiating Configuration..."

# Deploy pre-onboarding policies
log "Running pre-onboarding policies..."
$echo "Status: ${PRE_ONBOARDING_STATUS}" >> "$DEPNOTIFY_LOG"
$jamf policy -event pre-onboarding
log "Pre-onboarding policies done running"

# Deploy onboarding policies
log "Running onboarding policies..."
$echo "Status: ${ONBOARDING_STATUS}" >> "$DEPNOTIFY_LOG"
$jamf policy -event onboarding
log "Onboarding policies done running"

# Deploy post-onboarding policies
log "Running onboarding policies..."
$echo "Status: ${POST_ONBOARDING_STATUS}" >> "$DEPNOTIFY_LOG"
$jamf policy -event post-onboarding
log "Post-onboarding policies done running"

# Finishing up - tell the provisioner what's happening

# Modify the login window as necesary
log 'Setting the proper login window'
$jamf policy -event onboarding-loginwindow

# Fix disk permissions issues
log 'Fixing disk permissions'
$jamf policy -event onboarding-fixpermissions

# Write a provisioning complete receipt
log 'Marking onboarding process as finished'
$touch "$PROVISIONING_DONE_RECEIPT"

# Run a last recon
$echo "Status: Updating inventory..." >> "$DEPNOTIFY_LOG"
log "Running recon..."
$jamf recon

$echo "Command: MainTitle: ${COMPLETE_TITLE}"  >> "$DEPNOTIFY_LOG"
$echo "Command: MainText: ${COMPLETE_TEXT}"  >> "$DEPNOTIFY_LOG"
$echo "Status: ${COMPLETE_STATUS}" >> "$DEPNOTIFY_LOG"

# Kill caffeinate and restart with a 1 minute delay
log "Decaffeinating..."
kill "$caffeinatepid"

# Freeze the computer if necesary
log 'Freezing the computer if necesary'
$jamf policy -event onboarding-deepfreeze

log "Restarting in 2 minutes..."
$shutdown -r +2 &

log "Done!"

exit 0
