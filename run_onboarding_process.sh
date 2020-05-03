#!/bin/bash

# Bits of this were taken from:
# https://github.com/neilmartin83/MacADUK-2019/blob/master/example_provisioning_script.sh

# Script layout taken from:
# https://github.com/jamf/DEPNotify-Starter/blob/master/depNotify.sh


#########################################################################################
# General Information
#########################################################################################
# This script is designed to make implementation of NoMAD Login AD's Notify mechanism
# very easy with limited scripting knowledge. The sections below have variables that may be
# modified to customize the end user experience. DO NOT modify things in or below the
# CORE LOGIC area unless major testing and validation is performed.


#########################################################################################
# Policy Information
#########################################################################################
# Much of this script just runs policies by custom trigger from Jamf. The triggers are as
# follows, in the order they are called:

# 1. pre-onboarding
# Purpose: Intended to run policies to prepare the computer for the onboarding policies
# Suggested Usage:
#   - Install frameworks
#   - Set timezone
# 2. onboarding
# Purpose: Anything that needs to be installed/set during onboarding
# Suggested Usage:
#   - Install applications/settings
#   - Perform OS customizations
# 3. post-onboarding
# Purpose: Anything that needs to be done after onboarding policies are run
# Suggested Usage:
#   - Setting default applications
#   - Any other configuration that needs to be done after apps are installed
# 4. onboarding-cleanup
# Purpose: Any last policies to run before the computer restarts
# Suggested Usage:
#   - Enabling Deep Freeze
#   - Changing the login window
#   - Uninstalling NoMAD Login AD

# As a general guideline, don't include any policies that trigger restarts or need to be
# run in a user context.


#########################################################################################
# Registration Settings
#########################################################################################

# Whether or not the registration feature will be used
REGISTRATION_ENABLED=true

# Delay between each registration item being processed. Really only helps make sure each
# item can be seen in the progress bar, but at the cost of an added few seconds
REGISTRATION_ITEM_DELAY=3

# These settings are used to retrieve what's set during the "registration" part of the
# notify logon mechanism if enabled. The "LABEL" settings should match what's set in the
# similarly named items in the "menu.nomad.login.ad" plist or configuration profile, and
# the functions will be run verbatim if the "LABEL" variable is set. The value set during
# the registration phase for each item will be the item's prefix plus "VALUE". For
# example, the value for "text field 1" will be in "TEXT_FIELD_1_VALUE".
TEXT_FIELD_1_LABEL=''
TEXT_FIELD_1_FUNC() {

}

TEXT_FIELD_2_LABEL=''
TEXT_FIELD_2_FUNC() {

}

POPUP_BUTTON_1_LABEL=''
POPUP_BUTTON_1_FUNC() {

}

POPUP_BUTTON_2_LABEL=''
POPUP_BUTTON_2_FUNC() {

}

POPUP_BUTTON_3_LABEL=''
POPUP_BUTTON_3_FUNC() {

}

POPUP_BUTTON_4_LABEL=''
POPUP_BUTTON_4_FUNC() {

}


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
date='/bin/date'
defaults='/usr/bin/defaults'
echo='/bin/echo'
jamf='/usr/local/bin/jamf'
scutil='/usr/sbin/scutil'
shutdown='/sbin/shutdown'
sleep='/bin/sleep'
softwareupdate='/usr/sbin/softwareupdate'
touch='/usr/bin/touch'

# Settings
DEPNOTIFY_LOG='/var/tmp/depnotify.log'

PROVISIONING_DONE_RECEIPT='/private/var/db/receipts/com.depnotify.provisioning.done.bom'
REGISTRATION_DONE_RECEIPT='/private/var/db/receipts/com.depnotify.registration.done.bom'

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

# Wait for the setup assistant to complete before continuing
log "Waiting for Setup Assistant to complete..."
loggedInUser=$($scutil <<< "show State:/Users/ConsoleUser" | $awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
while [[ "$loggedInUser" == "_mbsetupuser" ]]; do
	$sleep 5
	loggedInUser=$($scutil <<< "show State:/Users/ConsoleUser" | $awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}     ')
done

# Let's continue
log "Setup Assistant complete, continuing..."

if [[ "$REGISTRATION_ENABLED" == 'true' ]]; then
    if [[ ! -f "$REGISTRATION_DONE_RECEIPT" ]]; then
        # Wait for the user data to be submitted...
        while [[ ! -f "$USERIO_PLIST" ]]; do
            log "Waiting for user data..."
            $sleep $REGISTRATION_ITEM_DELAY
        done

        $echo "Command: MainTitle: ${REGISTRATION_TITLE}"  >> "$DEPNOTIFY_LOG"

        # Process text field 1
        if [[ ! "$TEXT_FIELD_1_LABEL" == '' ]]; then
            log "Processing \"${TEXT_FIELD_1_LABEL}\"..."
            TEXT_FIELD_1_VALUE="$($defaults read "$USERIO_PLIST" "$TEXT_FIELD_1_LABEL")"
            $echo "Status: Setting ${TEXT_FIELD_1_LABEL} to ${TEXT_FIELD_1_VALUE}"  >> "$DEPNOTIFY_LOG"
            TEXT_FIELD_1_FUNC
            log "\"${TEXT_FIELD_1_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Process text field 2
        if [[ ! "$TEXT_FIELD_2_LABEL" == '' ]]; then
            log "Processing \"${TEXT_FIELD_2_LABEL}\"..."
            TEXT_FIELD_2_VALUE="$($defaults read "$USERIO_PLIST" "$TEXT_FIELD_2_LABEL")"
            $echo "Status: Setting ${TEXT_FIELD_2_LABEL} to ${TEXT_FIELD_2_VALUE}"  >> "$DEPNOTIFY_LOG"
            TEXT_FIELD_2_FUNC
            log "\"${TEXT_FIELD_2_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Process popup menu 1...
        if [[ ! "$POPUP_BUTTON_1_LABEL" == '' ]]; then
            log "Processing \"${POPUP_BUTTON_1_LABEL}\"..."
            POPUP_BUTTON_1_VALUE="$($defaults read "$USERIO_PLIST" "$POPUP_BUTTON_1_LABEL")"
            $echo "Status: Setting ${POPUP_BUTTON_1_LABEL} to ${POPUP_BUTTON_1_VALUE}"  >> "$DEPNOTIFY_LOG"
            POPUP_BUTTON_1_FUNC
            log "\"${POPUP_BUTTON_1_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Process popup menu 2...
        if [[ ! "$POPUP_BUTTON_2_LABEL" == '' ]]; then
            log "Processing \"${POPUP_BUTTON_2_LABEL}\"..."
            POPUP_BUTTON_2_VALUE="$($defaults read "$USERIO_PLIST" "$POPUP_BUTTON_2_LABEL")"
            $echo "Status: Setting ${POPUP_BUTTON_2_LABEL} to ${POPUP_BUTTON_2_VALUE}"  >> "$DEPNOTIFY_LOG"
            POPUP_BUTTON_2_FUNC
            log "\"${POPUP_BUTTON_2_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Process popup menu 3...
        if [[ ! "$POPUP_BUTTON_3_LABEL" == '' ]]; then
            log "Processing \"${POPUP_BUTTON_3_LABEL}\"..."
            POPUP_BUTTON_3_VALUE="$($defaults read "$USERIO_PLIST" "$POPUP_BUTTON_3_LABEL")"
            $echo "Status: Setting ${POPUP_BUTTON_3_LABEL} to ${POPUP_BUTTON_3_VALUE}"  >> "$DEPNOTIFY_LOG"
            POPUP_BUTTON_3_FUNC
            log "\"${POPUP_BUTTON_3_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Process popup menu 4...
        if [[ ! "$POPUP_BUTTON_4_LABEL" == '' ]]; then
            log "Processing \"${POPUP_BUTTON_4_LABEL}\"..."
            POPUP_BUTTON_4_VALUE="$($defaults read "$USERIO_PLIST" "$POPUP_BUTTON_4_LABEL")"
            $echo "Status: Setting ${POPUP_BUTTON_4_LABEL} to ${POPUP_BUTTON_4_VALUE}"  >> "$DEPNOTIFY_LOG"
            POPUP_BUTTON_4_FUNC
            log "\"${POPUP_BUTTON_4_LABEL}\" processed"
            $sleep $REGISTRATION_ITEM_DELAY
        fi

        # Write a registration complete receipt
        log 'Marking registration as complete'
        $touch "$REGISTRATION_DONE_RECEIPT"

        # Clear UserInput mech, just in case of restart
        log 'Clearing UserInput login mech'
        $authchanger -reset -preLogin NoMADLoginAD:Notify
        $killall -HUP NoMADLoginAD
    fi
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

# Reset the login window
log 'Resetting login window...'
$authchanger -reset

# Run any cleanup policies
log "Running onboarding cleanup policies..."
$jamf policy -event onboarding-cleanup
log "Onboarding cleanup policies done running"

# Kill caffeinate and restart with a 1 minute delay
log "Decaffeinating..."
kill "$caffeinatepid"

log "Restarting in 1 minute..."
$shutdown -r +1 &

log "Done!"

exit 0
