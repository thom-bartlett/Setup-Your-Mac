#!/bin/bash

####################################################################################################
#
# Setup Your Mac via swiftDialog
#
# Purpose: Leverages swiftDialog v1.11.2 (or later) (https://github.com/bartreardon/swiftDialog/releases) and 
# Jamf Pro Policy Custom Events to allow end-users to self-complete Mac setup post-enrollment
#
# Inspired by: Rich Trouton (@rtrouton) and Bart Reardon (@bartreardon)
#
# Based on:
# - Adam Codega (@adamcodega)'s https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh
# - James Smith (@smithjw)'s https://github.com/smithjw/swiftEnrolment
#
####################################################################################################
#
# Version 1.2.10, 04-Oct-2022, Dan K. Snelson (@dan-snelson)
#   Modifications for swiftDialog v2 (thanks, @bartreardon!)
#   - Added I/O pause to `dialog_update_setup_your_mac`
#   - Added `list: show` when displaying policy_array
#   - Re-ordered Setup Your Mac progress bar commands
#   More specific logging for various dialog update functions
#   Confirm Setup Assistant complete and user at Desktop (thanks, @ehemmete!)
# HISTORY
#
# Version 1.2.8, 17-Sep-2022, Dan K. Snelson (@dan-snelson)
#   Replaced "ugly" `completionAction` `if … then … else` with "more readabale" `case` statement (thanks, @pyther!)
#   Updated "method for determining laptop/desktop" (thanks, @acodega and @scriptingosx)
#   Additional tweaks discovered during internal production deployment
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version & Debug Mode (Jamf Pro Script Parameter 4)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="1.2.10"
debugMode="${4}"        # ( true | false, blank )
assetTagCapture="${5}"  # ( true | false, blank )
completionAction="${6}" # ( number of seconds to sleep | wait, blank )

if [[ ${debugMode} == "true" ]]; then
    scriptVersion="Dialog: v$(dialog --version) • Setup Your Mac: v${scriptVersion}"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for an allowed "Completion Action" value (Parameter 6); defaults to "wait"
# Options: ( number of seconds to sleep | wait, blank )
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case "${completionAction}" in
    '' | *[!0-9]*   ) completionAction="wait" ;;
    *               ) completionAction="sleep ${completionAction}" ;;
esac

if [[ ${debugMode} == "true" ]]; then
    echo "Using \"${completionAction}\" as the Completion Action"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogApp="/usr/local/bin/dialog"
setupYourMacCommandFile="/var/tmp/dialog_setup_your_mac.log"
setupYourMacPolicyArrayIconPrefixUrl="https://ics.services.jamfcloud.com/icon/hash_"
welcomeCommandFile="/var/tmp/dialog_welcome.log"
failureCommandFile="/var/tmp/dialog_failure.log"
loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
jamfBinary="/usr/local/bin/jamf"
logFolder="/private/var/log"
logName="enrollment.log"
exitCode="0"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPS TO BE INSTALLED
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://rumble.com/v119x6y-harvesting-self-service-icons.html
# - progresstext: The text to be displayed below the progress bar 
# - trigger: The Jamf Pro Policy Custom Event Name
# - path: The filepath for validation
#
# shellcheck disable=1112
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

policy_array=('
{
    "steps": [
        {
            "listitem": "Zoom",
            "icon": "92b8d3c448e7d773457532f0478a428a0662f694fbbfc6cb69e1fab5ff106d97",
            "progresstext": "Zoom is a videotelephony software program developed by Zoom Video Communications.",
            "trigger_list": [
                {
                    "trigger": "zoom",
                    "path": "/Applications/zoom.us.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Slack",
            "icon": "395aed4c1bf684b6abd0e5587deb60aa6774dc2a525fed2d9df2b95293b72b2c",
            "progresstext": "Slack is a new way to communicate with your team. It’s faster, better organized, and more secure than email.",
            "trigger_list": [
                {
                    "trigger": "slack",
                    "path": "/Applications/Slack.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Google Chrome",
            "icon": "12d3d198f40ab2ac237cff3b5cb05b09f7f26966d6dffba780e4d4e5325cc701",
            "progresstext": "Google Chrome is a browser that combines a minimal design with sophisticated technology to make the Web faster.",
            "trigger_list": [
                {
                    "trigger": "googlechromepkg",
                    "path": "/Applications/Google Chrome.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Google Drive",
            "icon": "06daf9a94b41e43bc9e9d3339018769f1862bf8b0646c2795996fa01d25db7ba",
            "progresstext": "Google Drive is a file storage and synchronization service developed by Google",
            "trigger_list": [
                {
                    "trigger": "googledrive",
                    "path": "/Applications/Google Drive.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Asana",
            "icon": "65887f3e16ae8e8d04059cbe89d91098544e66b758571bb4ae955261039e3ae2",
            "progresstext": "A way to easily communicate across teams, manage projects in one place, and reclaim more time with seamless collaboration.",
            "trigger_list": [
                {
                    "trigger": "asana",
                    "path": "/Applications/Asana.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Microsoft Word",
            "icon": "02d85f833abb84627237d2109ca240ca9ee4dc8d9db299996d45363e3034166d",
            "progresstext": "The trusted Word app lets you create, edit, view, and share your files with others quickly and easily.",
            "trigger_list": [
                {
                    "trigger": "microsoftword",
                    "path": "/Applications/Microsoft Word.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Microsoft Excel",
            "icon": "47b16c524f57020290de1a510a7abeb3aa992b15a583c2db74c4e28f3caf7e77",
            "progresstext": "Microsoft Excel is the industry leading spreadsheet software program, a powerful data visualization and analysis tool.",
            "trigger_list": [
                {
                    "trigger": "microsoftexcel",
                    "path": "/Applications/Microsoft Excel.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Okta Verify",
            "icon": "eec6872b106f8a959ba29514fd993fc67de4aa910ed750956b9a3cf1d5e0b22c",
            "progresstext": "Okta Verify is a lightweight app that allows you to securely access your apps via 2-step verification.",
            "trigger_list": [
                {
                    "trigger": "",
                    "path": "/Applications/Okta Verify.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Jamf Connect",
            "icon": "4cfbe08bd808b4fc6ebe6bef6cab758c119339241099860824a9944397f44d5d",
            "progresstext": "Jamf Connect Streamline Mac authentication and identity management.",
            "trigger_list": [
                {
                    "trigger": "jamfconnectenroll",
                    "path": "/Applications/Jamf Connect.app/Contents/Info.plist"
                }
            ]
        },
        {
            "listitem": "Arctic Wolf",
            "icon": "74b311abbe71dca3f425392d22ed4b60c0737175d1a0746dfb6a530330bd5683",
            "progresstext": "Arctic Wolf delivers dynamic 24x7 cybersecurity protection",
            "trigger_list": [
                {
                    "trigger": "Arctic Wolf",
                    "path": "/Library/ArcticWolfNetworks/Agent/bin/scout-client"
                }
            ]
        },
        {
            "listitem": "Sentinel One",
            "icon": "b19cf126be6e8c20f2906be53378161eefb6a88e9bffdd36d91ad5b1e36420d5",
            "progresstext": "Endpoint security software that defends every endpoint against every type of attack.",
            "trigger_list": [
                {
                    "trigger": "Sentinel One",
                    "path": "/Applications/SentinelOne/SentinelOne Extensions.app/Contents/Info.plist"
                }
            ]
        },

        {
            "listitem": "FileVault Disk Encryption",
            "icon": "f9ba35bd55488783456d64ec73372f029560531ca10dfa0e8154a46d7732b913",
            "progresstext": "FileVault is built-in to macOS and provides full-disk encryption to help prevent unauthorized access to your Mac.",
            "trigger_list": [
                {
                    "trigger": "filevault",
                    "path": "/Library/Preferences/com.apple.fdesetup.plist"
                }
            ]
        },
        {
            "listitem": "Final Configuration",
            "icon": "00d7c19b984222630f20b6821425c3548e4b5094ecd846b03bde0994aaf08826",
            "progresstext": "Finalizing VentureWell Configuration …",
            "trigger_list": [
                {
                    "trigger": "dockutil",
                    "path": ""
                },
                {
                    "trigger": "macOSLAPS",
                    "path": ""
                },
                {
                    "trigger": "computer-name",
                    "path": ""
                },
                {
                    "trigger": "remove admin",
                    "path": ""
                }
            ]
        },
        {
            "listitem": "Update Inventory",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "A listing of your Mac’s apps and settings — its inventory — is sent automatically to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "recon",
                    "path": ""
                }
            ]
        }
    ]
}
')



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome / Asset Tag" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

welcomeTitle="Welcome to your new Mac!"
welcomeMessage="Please wait while the following apps are downloaded and installed. These are just the core apps, many more are available in our [Self Service](jamfselfservice://) app which will show up in your Dock once this process is complete."

appleInterfaceStyle=$( /usr/bin/defaults read /Users/"${loggedInUser}"/Library/Preferences/.GlobalPreferences.plist AppleInterfaceStyle 2>&1 )

if [[ "${appleInterfaceStyle}" == "Dark" ]]; then
    welcomeIcon="https://wallpapercave.com/dwp2x/MGxxFCB.jpg"
else
    welcomeIcon="https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Apple_Computer_Logo_rainbow.svg/1028px-Apple_Computer_Logo_rainbow.svg.png?20201228132849"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Welcome / Asset Tag" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcomeCMD="$dialogApp \
--title \"$welcomeTitle\" \
--message \"$welcomeMessage\" \
--icon \"$welcomeIcon\" \
--iconsize 198 \
--button1text \"Continue\" \
--button2text \"Quit\" \
--button2disabled \
--infotext \"v$scriptVersion\" \
--ontop \
--titlefont 'size=26' \
--messagefont 'size=16' \
--textfield \"Asset Tag\",required=true,prompt=\"Please enter your Mac's seven-digit Asset Tag\",regex='^(AP|IP)?[0-9]{6,}$',regexerror=\"Please enter (at least) seven digits for the Asset Tag, optionally preceed by either 'AP' or 'IP'. \" \
--commandfile \"$welcomeCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Title, Message, Overlay Icon and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="Setting up your Mac"
message="Please wait while the following apps are downloaded and installed. These are just the core apps, many more are available in our [Self Service](jamfselfservice://) app which will show up in your Dock once this process is complete."
overlayicon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )

# Set initial icon based on whether the Mac is a desktop or laptop
if system_profiler SPPowerDataType | grep -q "Battery Power"; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Setup Your Mac" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogSetupYourMacCMD="$dialogApp \
--title \"none\" \
--bannerimage \"https://github.com/unfo33/venturewell-image/blob/main/setting_up_your_mac.jpeg?raw=true\" \
--message \"$message\" \
--icon \"$icon\" \
--progress \
--progresstext \"Initializing configuration …\" \
--button1text \"Quit\" \
--button1disabled \
--infotext \"v$scriptVersion\" \
--titlefont 'size=28' \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable 1 \
--commandfile \"$setupYourMacCommandFile\" "



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

failureTitle="Failure Detected"
failureMessage="Placeholder message; update in the finalise function"
failureIcon="SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# "Failure" Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogFailureCMD="$dialogApp \
--moveable \
--title \"$failureTitle\" \
--message \"$failureMessage\" \
--icon \"$failureIcon\" \
--iconsize 125 \
--width 650 \
--height 375 \
--position topright \
--button1text \"Close\" \
--infotext \"v$scriptVersion\" \
--titlefont 'size=22' \
--messagefont 'size=14' \
--commandfile \"$failureCommandFile\" "



#------------------------------- Edits below this line are optional -------------------------------#



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# JAMF Display Message (for fallback in case swiftDialog fails to install)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function jamfDisplayMessage() {
    echo "${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (thanks, Adam!)
# https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else
      jamfDisplayMessage "Dialog Team ID verification failed."
      exit 1
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
  else
    echo_logger "DIALOG: version $(dialog --version) found; proceeding..."
  fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Welcome / Asset Tag" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_update_welcome() {
    echo_logger "WELCOME DIALOG: $1"
    echo "$1" >> $welcomeCommandFile
    sleep 0.35
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Setup Your Mac" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_update_setup_your_mac() {
  echo_logger "SETUP YOUR MAC DIALOG: $1"
  echo "$1" >> $setupYourMacCommandFile
  sleep 0.35
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute a "Failure" Dialog command
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialog_update_failure(){
  echo_logger "FAILURE DIALOG: $1"
  echo "$1" >> $failureCommandFile
  sleep 0.35
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Finalise app installations
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function finalise(){

    if [[ "${jamfProPolicyTriggerFailure}" == "failed" ]]; then

        dialog_update_setup_your_mac "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        dialog_update_setup_your_mac "progress: complete"
        dialog_update_setup_your_mac "progresstext: Failures detected. Please click Continue for troubleshooting information."
        dialog_update_setup_your_mac "button1text: Continue …"
        dialog_update_setup_your_mac "button1: enable"
        echo_logger "Jamf Pro Policy Name Failures: ${jamfProPolicyPolicyNameFailures}"
        eval "${completionAction}"
        dialog_update_setup_your_mac "quit:"
        eval "${dialogFailureCMD}" & sleep 0.3
        if [[ ${debugMode} == "true" ]]; then
            dialog_update_failure "title: DEBUG MODE | $failureTitle"
        fi
        dialog_update_failure "message: A failure has been detected. Please complete the following steps:\n1. Reboot and login to your Mac  \n2. Login to Self Service  \n3. Re-run any failed policy listed below  \n\nThe following failed to install:  \n${jamfProPolicyPolicyNameFailures}  \n\n\n\nIf you need assistance, please contact support,  \nsupport@venturewell.org."
        dialog_update_failure "icon: SF=xmark.circle.fill,weight=bold,colour1=#BB1717,colour2=#F31F1F"
        eval "${completionAction}"
        dialog_update_failure "quit:"
        rm "$setupYourMacCommandFile"
        rm "$failureCommandFile"
        exit "${exitCode}"

    else

        dialog_update_setup_your_mac "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
        dialog_update_setup_your_mac "progress: complete"
        dialog_update_setup_your_mac "progresstext: Complete! Please enjoy your new Mac!"
        dialog_update_setup_your_mac "button1text: Quit"
        dialog_update_setup_your_mac "button1: enable"
        rm "$setupYourMacCommandFile"
        rm "$welcomeCommandFile"
        eval "${completionAction}" # Comment-out this line to NOT require user-interaction for successful completions
        exit "${exitCode}"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  smithjw's Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function echo_logger() {
    logFolder="${logFolder:=/private/var/log}"
    logName="${logName:=log.log}"

    mkdir -p $logFolder

    echo -e "$(date +%Y-%m-%d\ %H:%M:%S)  $1" | tee -a $logFolder/$logName
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON via osascript and JavaScript
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function get_json_value() {
    JSON="$1" osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# smithjw's sweet function to execute Jamf Pro Policy Custom Events
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function run_jamf_trigger() {
    trigger="$1"
    if [ "$debugMode" = true ]; then
        echo_logger "SETUP YOUR MAC DIALOG: DEBUG MODE: $jamfBinary policy -event $trigger"
        sleep 3
    elif [ "$trigger" == "recon" ]; then
        if [[ ${assetTagCapture} == "true" ]]; then
            echo_logger "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon -assetTag ${assetTag}"
            "$jamfBinary" recon -assetTag "${assetTag}"
        else
            echo_logger "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary recon"
            "$jamfBinary" recon
        fi
    else
        echo_logger "SETUP YOUR MAC DIALOG: RUNNING: $jamfBinary policy -event $trigger"
        "$jamfBinary" policy -event "$trigger"
    fi
}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
  echo "This script should be run as root"
  exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Initialize Log
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo_logger "Setup Your Mac (${scriptVersion}) by Dan K. Snelson. See: https://snelson.us/setup-your-mac"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Setup Assistant complete and user at Desktop
# Useful for triggering on Enrollment Complete and will not pause if run via Self Service
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dockStatus=$(/usr/bin/pgrep -x Dock)
echo_logger "Waiting for Desktop..."

while [[ "$dockStatus" == "" ]]; do
    echo_logger "Desktop is not loaded; waiting..."
    sleep 5
    dockStatus=$(/usr/bin/pgrep -x Dock)
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Display Welcome / Asset Tag and capture user's interaction
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${assetTagCapture} == "true" ]]; then

    assetTag=$( eval "$dialogWelcomeCMD" | awk -F " : " '{print $NF}' )

    if [[ -z ${assetTag} ]]; then
        returncode="2"
    else
        returncode="0"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Evaluate User Interaction at Welcome / Asset Tag Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ${assetTagCapture} == "true" ]]; then

    case ${returncode} in

        0)  ## Process exit code 0 scenario here
            echo_logger "WELCOME DIALOG: ${loggedInUser} entered an Asset Tag of ${assetTag} and clicked Continue"
            eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
            dialog_update_setup_your_mac "message: Asset Tag reported as \`${assetTag}\`. $message"
            if [[ ${debugMode} == "true" ]]; then
                dialog_update_setup_your_mac "title: DEBUG MODE | $title"
            fi
            ;;

        2)  ## Process exit code 2 scenario here
            echo_logger "WELCOME DIALOG: ${loggedInUser} clicked Quit when prompted to enter Asset Tag"
            exit 0
            ;;

        3)  ## Process exit code 3 scenario here
            echo_logger "WELCOME DIALOG: ${loggedInUser} clicked infobutton"
            /usr/bin/osascript -e "set Volume 3"
            /usr/bin/afplay /System/Library/Sounds/Tink.aiff
            ;;

        4)  ## Process exit code 4 scenario here
            echo_logger "WELCOME DIALOG: ${loggedInUser} allowed timer to expire"
            eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
            ;;

        *)  ## Catch all processing
            echo_logger "WELCOME DIALOG: Something else happened; Exit code: ${returncode}"
            exit 1
            ;;

    esac

else

    eval "${dialogSetupYourMacCMD[*]}" & sleep 0.3
    if [[ ${debugMode} == "true" ]]; then
        dialog_update_setup_your_mac "title: DEBUG MODE | $title"
    fi

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Iterate through policy_array JSON to construct the list for swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_step_length=$(get_json_value "${policy_array[*]}" "steps.length")
for (( i=0; i<dialog_step_length; i++ )); do
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    list_item_array+=("$listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    icon_url_array+=("$icon")
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set progress_total to the number of steps in policy_array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_total=$(get_json_value "${policy_array[*]}" "steps.length")
echo_logger "SETUP YOUR MAC DIALOG: progress_total=$progress_total"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

list_item_string=${list_item_array[*]/%/,}
dialog_update_setup_your_mac "list: ${list_item_string%?}"
for (( i=0; i<dialog_step_length; i++ )); do
    dialog_update_setup_your_mac "listitem: index: $i, icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon_url_array[$i]}, status: pending, statustext: Pending …"
done
dialog_update_setup_your_mac "list: show"


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Set initial progress bar
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

progress_index=0
dialog_update_setup_your_mac "progress: $progress_index"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Close Welcome / Asset Tag dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialog_update_welcome "quit:"
sleep 0.3



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This for loop will iterate over each distinct step in the policy_array array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

for (( i=0; i<dialog_step_length; i++ )); do

    # Increment the progress bar
    dialog_update_setup_your_mac "progress: $(( i * ( 100 / progress_total ) ))"

    # Creating initial variables
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    progresstext=$(get_json_value "${policy_array[*]}" "steps[$i].progresstext")

    trigger_list_length=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list.length")

    # If there's a value in the variable, update running swiftDialog

    if [[ -n "$listitem" ]]; then dialog_update_setup_your_mac "listitem: index: $i, status: wait, statustext: Installing …, "; fi
    if [[ -n "$icon" ]]; then dialog_update_setup_your_mac "icon: ${setupYourMacPolicyArrayIconPrefixUrl}${icon}"; fi
    if [[ -n "$progresstext" ]]; then dialog_update_setup_your_mac "progresstext: $progresstext"; fi
    if [[ -n "$trigger_list_length" ]]; then
        for (( j=0; j<trigger_list_length; j++ )); do
            # Setting variables within the trigger_list
            trigger=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].trigger")
            path=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].path")

            # If the path variable has a value, check if that path exists on disk
            if [[ -f "$path" ]]; then
                echo_logger "SETUP YOUR MAC DIALOG: INFO: $path exists, moving on"
                 if [[ "$debugMode" = true ]]; then sleep 3; fi
            else
                run_jamf_trigger "$trigger"
            fi
        done
    fi

    # Validate the expected path exists
    echo_logger "SETUP YOUR MAC DIALOG: Testing for \"$path\" …"
    if [[ -f "$path" ]] || [[ -z "$path" ]]; then
        dialog_update_setup_your_mac "listitem: index: $i, status: success, statustext: Installed"
    else
        dialog_update_setup_your_mac "listitem: index: $i, status: fail, statustext: Failed"
        jamfProPolicyTriggerFailure="failed"
        jamfProPolicyPolicyNameFailures+="• $listitem  \n"
        exitCode="1"
    fi

    sleep 0.3

done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Complete processing and enable the "Done" button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

finalise