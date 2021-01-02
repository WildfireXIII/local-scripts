#!/bin/bash


RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
MAGENTA="\033[0;35m"
RED_L="\033[1;31m"
GREEN_L="\033[1;32m"
YELLOW_L="\033[1;33m"
MAGENTA_L="\033[1;35m"
CYAN_L="\033[1;36m"
RESET="\033[0m"

echo -e "\n\n${CYAN_L}Archlinux setup script v21.1${RESET}\n"

output="/dev/tty"
show_output="/dev/tty"

# https://stackoverflow.com/questions/2853803/how-to-echo-shell-commands-as-they-are-executed
# NOTE: destroys quoting, use with care
show() { echo -e "${MAGENTA}\$ $@${RESET}" ; "$@">$output ; }

step() { STEP="---- $1 ----"; echo "$STEP" ; }


checkfail()
{
	if [ $? -eq 0 ]; then
		echo -e "[ ${GREEN_L}OK${RESET} ] $STEP"
		return 0
	else
		echo -e "[${RED_L}FAIL${RESET}] $STEP"
		echo -e "Suggested fixes:"
		for suggestion in "$@"
		do
			echo -e "\t* $suggestion"
		done
		return 1
	fi
}

stopiffail()
{
	if [ $? -eq 1 ]; then
		echo -e "${RED}Fatal error, exiting...${RESET}"
		exit
	fi
}

cedeiffail()
{
	if [ $? -eq 1 ]; then
		cede "$1"
	fi
}

cede() 
{
	echo -e "\n${YELLOW_L}Ceding control to user for manual intervention. Run ${RESET}${MAGENTA_L}fg${RESET}${YELLOW_L} to resume${RESET}"
	echo -e "(Advised intervention: $1)"
	suspend
	echo -e "\n${YELLOW_L}Script granted control again, resuming happily!${RESET}"
}

# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
prompt_yn()
{
	while true; do
		read -p "$1 [y/n]: " yn
		case $yn in
			[Yy\n]* ) return 0; break;;
			[Nn]* ) return 1; break;;
			* ) echo "Please answer 'y' or 'n'";;
		esac
	done
}

# https://stackoverflow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
prompt_yn_default()
{
	while true; do
		read -p "$1 [Y/n]: " yn
		if [[ $yn =~ ^(Y|y) ]] || [[ -z $yn ]]; then
			return 0
		elif [[ $yn =~ ^(N|n) ]]; then
			return 1
		else
			echo "Please answer 'y' or 'n'"
		fi
	done
}


set -m

step "Verifying boot mode (are we in UEFI?)"
show ls /sys/firmware/efi/efivars >$show_output
checkfail "You're not booted in UEFI mode. Check ISO and BIOS settings?"
stopiffail

step "Checking internet connection"
show ping -c 1 -q google.com
checkfail "Connect with ${MAGENTA_L}nmtui${RESET}" "Connect with ${MAGENTA_L}wifi-menu${RESET}"
cedeiffail "establish internet connection"

step "Partitioning disks"
prompt_yn_default "Auto partition the disks? (Typing no will cede control)"
cedeiffail "partition disks"


show ls /dev/sd* /dev/nvme* /mmcblk*
read -p "Please choose disk to partition: " disk
echo "You chose:"
