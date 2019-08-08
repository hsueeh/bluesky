#!/bin/sh

parameters="${1}${2}${3}${4}${5}${6}${7}${8}${9}"

Escape_Variables()
{
	text_progress="\033[38;5;113m"
	text_success="\033[38;5;113m"
	text_warning="\033[38;5;221m"
	text_error="\033[38;5;203m"
	text_message="\033[38;5;75m"

	text_bold="\033[1m"
	text_faint="\033[2m"
	text_italic="\033[3m"
	text_underline="\033[4m"

	erase_style="\033[0m"
	erase_line="\033[0K"

	move_up="\033[1A"
	move_down="\033[1B"
	move_foward="\033[1C"
	move_backward="\033[1D"
}

Parameter_Variables()
{
	if [[ $parameters == *"-v"* || $parameters == *"-verbose"* ]]; then
		verbose="1"
		set -x
	fi
}

Path_Variables()
{
	script_path="${0}"
	directory_path="${0%/*}"

	patch_resources_path="$directory_path/resources/patch"
	revert_resources_path="$directory_path/resources/revert"
}

Input_Off()
{
	stty -echo
}

Input_On()
{
	stty echo
}

Output_Off()
{
	if [[ $verbose == "1" ]]; then
		"$@"
	else
		"$@" &>/dev/null
	fi
}

Check_Environment()
{
	echo ${text_progress}"> Checking system environment."${erase_style}
	if [ ! -d /Install\ *.app ]; then
		echo ${move_up}${erase_line}${text_success}"+ System environment check passed."${erase_style}
	fi
	if [ -d /Install\ *.app ]; then
		echo ${text_error}"- System environment check failed."${erase_style}
		echo ${text_message}"/ This tool is not supported in the Recovery environment."${erase_style}
		Input_On
		exit
	fi
}

Check_Root()
{
	echo ${text_progress}"> Checking for root permissions."${erase_style}
	if [[ $(whoami) == "root" ]]; then
		root_check="passed"
		echo ${move_up}${erase_line}${text_success}"+ Root permissions check passed."${erase_style}
	fi
	if [[ ! $(whoami) == "root" ]]; then
		root_check="failed"
		echo ${text_error}"- Root permissions check failed."${erase_style}
		echo ${text_message}"/ Run this tool with root permissions."${erase_style}
		Input_On
		exit
	fi
}

Check_SIP()
{
	echo ${text_progress}"> Checking System Integrity Protection status."${erase_style}
	if [[ $(csrutil status | grep status) == *disabled* || $(csrutil status | grep status) == *unknown* ]]; then
		echo ${move_up}${erase_line}${text_success}"+ System Integrity Protection status check passed."${erase_style}
	else
		echo ${text_error}"- System Integrity Protection status check failed."${erase_style}
		echo ${text_message}"/ Run this tool with System Integrity Protection disabled."${erase_style}
		Input_On
		exit
	fi
}

Check_Resources()
{
	echo ${text_progress}"> Checking for resources."${erase_style}
	if [[ -d "$patch_resources_path" && -d "$revert_resources_path" ]]; then
		resources_check="passed"
		echo ${move_up}${erase_line}${text_success}"+ Resources check passed."${erase_style}
	fi
	if [[ ! -d "$patch_resources_path" || ! -d "$revert_resources_path" ]]; then
		resources_check="failed"
		echo ${text_error}"- Resources check failed."${erase_style}
	fi
}

Check_Internet()
{
	echo ${text_progress}"> Checking for internet connectivity."${erase_style}
	if [[ $(ping -c 5 www.google.com) == *transmitted* && $(ping -c 5 www.google.com) == *received* ]]; then
		echo ${move_up}${erase_line}${text_success}"+ Internet connectivity check passed."${erase_style}
		internet_check="passed"
	else
		echo ${text_error}"- Internet connectivity check failed."${erase_style}
		internet_check="failed"
	fi
}

Check_Options()
{
	if [[ $resources_check == "failed" && $internet_check == "failed" ]]; then
		echo ${text_error}"- Resources check and internet connectivity check failed"${erase_style}
		echo ${text_message}"/ Run this tool with the required resources and/or an internet connection."${erase_style}
		Input_On
		exit
	fi
}

Input_Volume()
{
	echo ${text_message}"/ What volume would you like to use?"${erase_style}
	echo ${text_message}"/ Input a volume name."${erase_style}
	for volume_path in /Volumes/*; do 
		volume_name="${volume_path#/Volumes/}"
		if [[ ! "$volume_name" == com.apple* ]]; then
			echo ${text_message}"/     ${volume_name}"${erase_style} | sort -V
		fi
	done
	Input_On
	read -e -p "/ " volume_name
	Input_Off

	volume_path="/Volumes/$volume_name"

	if [[ $(diskutil info "$volume_name"|grep "Mount Point") == *"/" && ! $(diskutil info "$volume_name"|grep "Mount Point") == *"/Volumes" ]]; then
		sudo mount -uw /
	fi
}

Check_Volume_Version()
{
	echo ${text_progress}"> Checking system version."${erase_style}	
	volume_version="$(defaults read "$volume_path"/System/Library/CoreServices/SystemVersion.plist ProductVersion)"
	volume_version_short="$(defaults read "$volume_path"/System/Library/CoreServices/SystemVersion.plist ProductVersion | cut -c-5)"

	volume_build="$(defaults read "$volume_path"/System/Library/CoreServices/SystemVersion.plist ProductBuildVersion)"
	echo ${move_up}${erase_line}${text_success}"+ Checked system version."${erase_style}
}

Check_Volume_Support()
{
	echo ${text_progress}"> Checking system support."${erase_style}
	if [[ $volume_version_short == "10.1"[4-5] ]]; then
		echo ${move_up}${erase_line}${text_success}"+ System support check passed."${erase_style}
	else
		echo ${text_error}"- System support check failed."${erase_style}
		echo ${text_message}"/ Run this tool on a supported system."${erase_style}
		Input_On
		exit
	fi
}

Check_Graphics_Card()
{
	echo ${text_progress}"> Detecting graphics card."${erase_style}
	if [[ ! "$(system_profiler SPDisplaysDataType | grep Metal)" == *"Supported"* ]]; then
		echo ${move_up}${erase_line}${text_success}"+ Not-Metal graphics card detected."${erase_style}
	else
		echo ${text_warning}"! Metal graphics card detected."${erase_style}
		echo ${text_warning}"! This tool is not intended for Metal cards."${erase_style}
		echo ${text_message}"/ Input an operation number."${erase_style}
		echo ${text_message}"/     1 - Abort"${erase_style}
		echo ${text_message}"/     2 - Proceed"${erase_style}
		Input_On
		read -e -p "/ " operation_graphis_card
		Input_Off

		if [[ $operation == "1" ]]; then
			Input_On
			exit
		fi
	fi
}

Input_Operation()
{
	echo ${text_message}"/ What operation would you like to run?"${erase_style}
	echo ${text_message}"/ Input an operation number."${erase_style}
	echo ${text_message}"/     1 - Install SkyLight patch"${erase_style}
	echo ${text_message}"/     2 - Remove SkyLight patch"${erase_style}
	echo ${text_message}"/     3 - Install HIToolbox patch"${erase_style}
	echo ${text_message}"/     4 - Remove HIToolbox patch"${erase_style}
	echo ${text_message}"/     5 - Install both patches"${erase_style}
	echo ${text_message}"/     6 - Remove both patches"${erase_style}
	Input_On
	read -e -p "/ " operation
	Input_Off

	if [[ $resources_check == "passed" ]]; then
		Prepare_Resources
	fi
	if [[ $resources_check == "failed" ]]; then
		Download_Resources
	fi

	if [[ $operation == "1" || $operation == "5" ]]; then
		Backup_SkyLight
		Patch_SkyLight
		Backup_New_SkyLight
	fi
	if [[ $operation == "2" || $operation == "6" ]]; then
		Backup_SkyLight
		Remove_SkyLight
		Backup_New_SkyLight
	fi

	if [[ $operation == "3" || $operation == "5" ]]; then
		Backup_HIToolbox
		Patch_HIToolbox
		Backup_New_HIToolbox
	fi
	if [[ $operation == "4" || $operation == "6" ]]; then
		Backup_HIToolbox
		Remove_HIToolbox
		Backup_New_HIToolbox
	fi
}

Prepare_Resources()
{
	echo ${text_progress}"> Preparing local resources."${erase_style}
	chmod +x "$directory_path"/resources/skylight_var.sh
	chmod +x "$directory_path"/resources/hitoolbox_var.sh
	
	source "$directory_path"/resources/skylight_var.sh
	source "$directory_path"/resources/hitoolbox_var.sh
	echo ${move_up}${erase_line}${text_success}"+ Prepared local resources."${erase_style}
}

Download_Resources()
{
	echo ${text_progress}"> Downloading internet resources."${erase_style}
	curl -L -s -o /tmp/bluesky-resources.zip https://github.com/rmc-team/bluesky-resources/archive/master.zip
	unzip -q /tmp/bluesky-resources.zip -d /tmp

	patch_resources_path="/tmp/bluesky-resources-master/resources/patch"
	revert_resources_path="/tmp/bluesky-resources-master/resources/revert"

	chmod +x /tmp/bluesky-resources-master/resources/skylight_var.sh
	chmod +x /tmp/bluesky-resources-master/resources/hitoolbox_var.sh

	source /tmp/bluesky-resources-master/resources/skylight_var.sh
	source /tmp/bluesky-resources-master/resources/hitoolbox_var.sh
	echo ${move_up}${erase_line}${text_success}"+ Downloaded internet resources."${erase_style}
}

Backup_SkyLight()
{
	echo ${text_progress}"> Backing up current SkyLight."${erase_style}
	if [[ -e "$volume_path"/Users/Shared/SkyLight-Backup ]]; then
		rm "$volume_path"/Users/Shared/SkyLight-Backup
	fi

	if [[ $volume_version_short == "10.14" ]]; then
		cp "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight "$volume_path"/Users/Shared/SkyLight-Backup
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		cp "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLightOriginal "$volume_path"/Users/Shared/SkyLight-Backup
	fi
	echo ${move_up}${erase_line}${text_success}"+ Backed up current SkyLight."${erase_style}
}

Patch_SkyLight()
{
	echo ${text_progress}"> Installing SkyLight patch."${erase_style}
	if [[ $volume_version_short == "10.14" ]]; then
		rm "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight
		cp "$patch_resources_path"/SkyLight/${!skylight_folder_version}/SkyLight "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		rm "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLightOriginal
		cp "$patch_resources_path"/SkyLight/${!skylight_folder_build}/SkyLightOriginal "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A
	fi
	echo ${move_up}${erase_line}${text_success}"+ Installed SkyLight patch."${erase_style}
}

Remove_SkyLight()
{
	echo ${text_progress}"> Removing SkyLight patch."${erase_style}
	if [[ $volume_version_short == "10.14" ]]; then
		rm "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight
		cp "$revert_resources_path"/SkyLight/${!skylight_folder_version}/SkyLight "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		rm "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLightOriginal
		cp "$revert_resources_path"/SkyLight/${!skylight_folder_build}/SkyLightOriginal "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A
	fi
	echo ${move_up}${erase_line}${text_success}"+ Removed SkyLight patch."${erase_style}
}

Backup_New_SkyLight()
{
	echo ${text_progress}"> Backing up new SkyLight."${erase_style}
	if [[ -e "$volume_path"/Users/Shared/SkyLight-BlueSky ]]; then
		rm "$volume_path"/Users/Shared/SkyLight-BlueSky
	fi

	if [[ $volume_version_short == "10.14" ]]; then
		cp "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight "$volume_path"/Users/Shared/SkyLight-BlueSky
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		cp "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLightOriginal "$volume_path"/Users/Shared/SkyLight-BlueSky
	fi
	echo ${move_up}${erase_line}${text_success}"+ Backed up new SkyLight."${erase_style}
}

Backup_HIToolbox()
{
	echo ${text_progress}"> Backing up current HIToolbox."${erase_style}
	if [[ -e "$volume_path"/Users/Shared/HIToolbox-Backup ]]; then
		rm "$volume_path"/Users/Shared/HIToolbox-Backup
	fi

	cp "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox "$volume_path"/Users/Shared/HIToolbox-Backup
	echo ${move_up}${erase_line}${text_success}"+ Backed up current HIToolbox."${erase_style}
}

Patch_HIToolbox()
{
	echo ${text_progress}"> Installing HIToolbox patch."${erase_style}
	if [[ $volume_version_short == "10.14" ]]; then
		rm "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox
		cp "$patch_resources_path"/HIToolbox/${!hitoolbox_folder_version}/HIToolbox "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		rm "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox
		cp "$patch_resources_path"/HIToolbox/${!hitoolbox_folder_build}/HIToolbox "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A
	fi
	echo ${move_up}${erase_line}${text_success}"+ Installed HIToolbox patch."${erase_style}
}

Remove_HIToolbox()
{
	echo ${text_progress}"> Removing HIToolbox patch."${erase_style}
	if [[ $volume_version_short == "10.14" ]]; then
		rm "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox
		cp "$revert_resources_path"/HIToolbox/${!hitoolbox_folder_version}/HIToolbox "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A
	fi

	if [[ $volume_version_short == "10.15" ]]; then
		rm "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox
		cp "$revert_resources_path"/HIToolbox/${!hitoolbox_folder_build}/HIToolbox "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A
	fi
	echo ${move_up}${erase_line}${text_success}"+ Removed HIToolbox patch."${erase_style}
}

Backup_New_HIToolbox()
{
	echo ${text_progress}"> Backing up new HIToolbox."${erase_style}
	if [[ -e "$volume_path"/Users/Shared/HIToolbox-BlueSky ]]; then
		rm "$volume_path"/Users/Shared/HIToolbox-BlueSky
	fi

	cp "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/Versions/A/HIToolbox "$volume_path"/Users/Shared/HIToolbox-BlueSky
	echo ${move_up}${erase_line}${text_success}"+ Backed up new HIToolbox."${erase_style}
}

Repair()
{
	chown -R 0:0 "$@"
	chmod -R 755 "$@"
}

Repair_Permissions()
{
	echo ${text_progress}"> Repairing permissions."${erase_style}
	Repair "$volume_path"/System/Library/PrivateFrameworks/SkyLight.framework
	Repair "$volume_path"/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework
	echo ${move_up}${erase_line}${text_success}"+ Repaired permissions."${erase_style}
}

Restart()
{
	echo ${text_progress}"> Removing temporary files."${erase_style}
	Output_Off rm /tmp/bluesky-resources.zip
	Output_Off rm -R /tmp/bluesky-resources-master
	echo ${move_up}${erase_line}${text_success}"+ Removed temporary files."${erase_style}

	if [[ $(diskutil info "$volume_name"|grep "Mount Point") == *"/" && ! $(diskutil info "$volume_name"|grep "Mount Point") == *"/Volumes" ]]; then
		echo ${text_message}"/ Your machine will restart soon."${erase_style}
		echo ${text_message}"/ Thank you for using BlueSky."${erase_style}
		reboot
	else
		echo ${text_message}"/ Thank you for using BlueSky."${erase_style}
		Input_On
		exit
	fi
}

Input_Off
Escape_Variables
Parameter_Variables
Path_Variables
Check_Environment
Check_Root
Check_SIP
Check_Resources
Check_Internet
Check_Options
Input_Volume
Check_Volume_Version
Check_Volume_Support
Check_Graphics_Card
Input_Operation
Repair_Permissions
Restart