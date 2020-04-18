# Jamf Scripts

A collection of standalone scripts to add to a Jamf instance.

## Included Scripts

### Clear Desktop Picture Cache
#### Purpose
Clears the cached desktop picture and lock screen. Affects all users.

#### Uses
* Run after either programmatically changing a user's desktop picture.
* Run after updating the picture currently set as a user's desktop picture.

#### Variables
None

### Create Local Account From Assigned User
#### Purpose
Creates a local user account based on the assigned user in Jamf. Prompts a password to be set the first time that user signs in.

### Uses
* If you're assigning devices to users in a NoMAD Login AD or DEPNotify workflow.
* If you're manually assigning users in Jamf (not that I'd recommend this).

#### Variables
1. Jamf URL
2. API Username
3. API Password

### Run Onboarding Process
#### Purpose
Kicks off and manages the running of policies at enrollment. Meant to integrate with the "notify" mechanism of NoMAD Login AD. The configuration is heavily tied to the environment I wrote it for, so I'd reccomend modifying it to fit your environment.

### Uses
* To run policies in a specific order on enrollment.
* To prevent the computer from being signed into until certain policies have run.

#### Variables
All variables are set in the script itself.

### Set Computer Name
#### Purpose
Changes the computer name to the format USER_ID-MAKE-YEAR (e.g. ASR230-Macmini-2018).

### Uses
* To change the device name to an org's standard format.

#### Variables
1. Jamf URL
2. API Username
3. API Password

## FAQ

Why did you upload these to GitHub?
> I wanted a central place to store any one-off scripts I had created for my organization's Jamf instance.

Can I use/change these for my organization?
> Sure. I can't guarantee they'll work as expected in your environment, though. Additionally, wnot all of the scripts made it out of our dev environment and into production, just because our needs changed.

A script that used to be here's now missing. Where can I find it?
> Some of these were intended to be part of a larger project or app. The missing script was probably moved into a different repository on [my GitHub](https://github.com/targendaz2).

Where can I go for help with Jamf or Macs in general?
>[Jamf Nation](https://www.jamf.com/jamf-nation/), the [MacSysAdmin subreddit](https://www.reddit.com/r/macsysadmin/), and the [MacAdmins Slack channel](https://macadmins.slack.com) are all great resources for help managing Macs in an enterprise environment.
