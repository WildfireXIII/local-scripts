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

show_output="/dev/tty"




# https://stackoverflow.com/questions/2853803/how-to-echo-shell-commands-as-they-are-executed
# NOTE: destroys quoting, use with care
show() { echo -e "${MAGENTA}\$ $@${RESET}" ; "$@" ; }

step() { STEP="---- $1 ----"; echo "$STEP" ; }


checkfail() {
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

stopiffail() {
	if [ $? -eq 1 ]; then
		echo -e "${RED}Fatal error, exiting...${RESET}"
		exit
	fi
}

cedeiffail() {
	if [ $? -eq 1 ]; then
		cede "$1"
		return 1
	fi
	return 0
}

cede() {
	echo -e "\n${YELLOW_L}Ceding control to user for manual intervention. Run ${RESET}${MAGENTA_L}fg${RESET}${YELLOW_L} to resume${RESET}"
	echo -e "(Advised intervention: $1)"
	suspend
	echo -e "\n${YELLOW_L}Script granted control again, resuming happily!${RESET}"
}

# https://stackoverflow.com/questions/226703/how-do-i-prompt-for-yes-no-cancel-input-in-a-linux-shell-script
prompt_yn() {
	while true; do
		read -p "$1 [y/n]: " yn
		case $yn in
			[Yy]* ) return 0; break;;
			[Nn]* ) return 1; break;;
			* ) echo "Please answer 'y' or 'n'";;
		esac
	done
}

# https://stackoverflow.com/questions/1885525/how-do-i-prompt-a-user-for-confirmation-in-bash-script
prompt_yn_default() {
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


run_fdisk() {
read -r -d '' default_fdisk_partitioning <<-EOF
	g # clear the in memory partition table (GPT)
	  # ---
	n # new partition
	1 # partition number 1
	# default - start at beginning of disk 
	+500M # 500 MB boot parttion
	y # in case there's a vfat sig removal request
	t # change partition type
	1 # change type to 1 (EFI System)
	  # ---
	n # new partition
	2 # partion number 2
	# default, start immediately after preceding partition
	$2 # make swap space
	t # change partition type
	2 # select partition 2 
	19 # change type to 19 (Linux swap)
	  # ---
	n # new partition
	3 # partition number 3
	# default, start immediately after preceding partition
	# default, extend partition to end of disk
	  # ---
	p # print the in-memory partition table
	w # write the partition table
	q # and we're done
EOF

	echo -e "\n\n${RED_L}Please confirm the following commands:${RESET}"
	echo -e "$default_fdisk_partitioning"
	echo -e "\n${RED_L}ATTENTION. CONFIRMATION REQUIRED.${RESET}"
	echo -e "These commands will be applied to disk: $1"
	prompt_yn "Please confirm. Typing no will NOT RUN fdisk and cede control"
	cedeiffail "partition disks, note that the suggested partition table is:\n
	/mnt/efi\tEFI system partition (1)\t+260M
	[SWAP]\t\tLinux swap (19)\t\t\t+512M
	/mnt\t\tLinux filesystem [root] (20)\t(remainder)"
	autoPartition="$?"

	echo "Running fdisk..."
	echo -e "$default_fdisk_partitioning" | sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' | fdisk $1
	checkfail "Manually partition the disks"
	cedeiffail "partition disks, note that the suggested partition table is:\n
	/mnt/efi\tEFI system partition (1)\t+260M
	[SWAP]\t\tLinux swap (19)\t\t\t+512M
	/mnt\t\tLinux filesystem [root] (20)\t(remainder)"
	autoPartition="$?"
}

getSwapPartition()
{
	if [ $autoPartition -eq 0 ]; then
		if [[ $disk == /dev/sd* ]]; then
			swapPartition=${disk}2
		else
			ls /dev | grep -E "^sd|^nvme|^mmcblk"
			read -p "Please choose swap partition: " swapPartition
			swapPartition=/dev/$swapPartition
		fi
	fi
	echo "Swap partition: $swapPartition"
}

getRootPartition()
{
	if [ $autoPartition -eq 0 ]; then
		if [[ $disk == /dev/sd* ]]; then
			rootPartition=${disk}3
		else
			ls /dev | grep -E "^sd|^nvme|^mmcblk"
			read -p "Please choose root partition: " rootPartition
			rootPartition=/dev/$rootPartition
		fi
	fi
	echo "Root partition: $rootPartition"
}

getEFIPartition()
{
	if [ $autoPartition -eq 0 ]; then
		if [[ $disk == /dev/sd* ]]; then
			efiPartition=${disk}1
		else
			ls /dev | grep -E "^sd|^nvme|^mmcblk"
			read -p "Please choose EFI partition: " efiPartition
			efiPartition=/dev/$rootPartition
		fi
	fi
	echo "EFI partition: $efiPartition"
}


set -m

step "Verifying boot mode (are we in UEFI?)"
show ls /sys/firmware/efi/efivars >$show_output
checkfail "You're not booted in UEFI mode. Check ISO and BIOS settings?"
stopiffail

step "Checking internet connection"
show ping -c 1 -q google.com
checkfail "Connect with ${MAGENTA_L}nmtui${RESET}" "Connect with ${MAGENTA_L}wifi-menu${RESET}" "Connect with ${MAGENTA_L}iwctl device list; iwctl station [device] connect SSID${RESET}"
cedeiffail "establish internet connection"

step "Partitioning disks"
prompt_yn_default "Auto partition the disks? (Typing no will cede control)"
cedeiffail "partition disks, note that the suggested partition table is:\n
/mnt/efi\tEFI system partition (1)\t+260M
[SWAP]\t\tLinux swap (19)\t\t\t+512M
/mnt\t\tLinux filesystem [root] (20)\t(remainder)"
autoPartition="$?"

if [ $autoPartition -eq 0 ]; then
	ls /dev | grep -E "^sd|^nvme|^mmcblk"
	read -p "Please choose disk to partition: " disk
	disk=/dev/$disk
	echo "You chose: $disk"
	read -p "Enter swap space in number of gb: " gb
	gb="+${gb}G"
	echo "You chose: ${gb}"
	run_fdisk $disk $gb
fi

prompt_yn_default "Auto format and mount? (Typing no will cede control)"
cedeiffail "format and mount partitions\n${MAGENTA_L}mkfs.ext4 [rootpart]\nmkswap [swap]\nmount [rootpart] /mnt\nswapon [swap]${RESET}"
autoMount="$?"

if [ $autoMount -eq 0 ]; then
	step "Formatting EFI partition"
	getEFIPartition
	show mkfs.fat -F32 $efiPartition
	checkfail "?"
	cedeiffail "format EFI system partition as fat32"
	
	step "Formatting root partition"
	getRootPartition
	show mkfs.ext4 $rootPartition
	checkfail "?"
	cedeiffail "format root partition as ext4"

	step "Formatting swap partition"
	getSwapPartition
	show mkswap $swapPartition
	checkfail "?"

	step "Mount root partition"
	show mount $rootPartition /mnt
	checkfail "?"
	cedeiffail "mount root partition to /mnt"
	
	step "Mount EFI partition"
	show mkdir -p /mnt/boot
	show mount $efiPartition /mnt/boot
	checkfail "?"
	cedeiffail "mount efi partition to /mnt/boot"
	
	step "Mount swap partition"
	show swapon $swapPartition 
	checkfail "?"
fi

step "Get mirrors"
echo -e "${MAGENTA}$ curl 'https://archlinux.org/mirrorlist/?country=US&protocol=http&ip_version=4' | sed 's/^.//' > /etc/pacman.d/mirrorlist${RESET}"
curl "https://archlinux.org/mirrorlist/?country=US&protocol=http&ip_version=4" | sed "s/^.//" > /etc/pacman.d/mirrorlist
checkfail "Go to 'https://archlinux.org/mirrorlist', generate a list and copy it into /etc/pacman.d/mirrorlist"
cedeiffail "update mirrorlist in /etc/pacman.d/mirrorlist"

step "Install essential packages"
show pacstrap /mnt base linux linux-firmware vim git networkmanager grub efibootmgr
checkfail "?"
stopiffail

step "Fstab the shit out of it"
show mkdir -p /mnt/etc 
echo -e "${MAGENTA}$ genfstab -U /mnt >> /mnt/etc/fstab${RESET}" # seems to fail inside show?
genfstab -U /mnt >> /mnt/etc/fstab
checkfail "?"
cedeiffail "ensure that /mnt/etc/fstab was generated correctly"

ch="arch-chroot /mnt"

step "Link timezone"
show $ch ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
checkfail "Manually set timezone with ${MAGENTA}$ch ln -sf /usr/share/zoneinfo/[region]/[city] /etc/localtime${RESET}"
cedeiffail "link timezone in /etc/localtime"

step "Set hardwareclock"
show $ch hwclock --systohc
checkfail "?"

step "Set localization"
show $ch locale-gen
checkfail "?"

step "Set locale.conf"
echo -e "${MAGENTA}$ $ch bash -c \"echo 'LANG=en_us.UTF-8' > /etc/locale.conf${RESET}\""
$ch bash -c "echo 'LANG=en_us.UTF-8' > /etc/locale.conf"
checkfail "?"

step "Set hostname"
read -p "System hostname: " syshostname
echo -e "${MAGENTA}$ $ch bash -c \"echo $syshostname > /etc/hostname${RESET}\""
$ch bash -c "echo $syshostname > /etc/hostname"
checkfail "?"

step "Set hosts"
$ch bash -c "echo -e \"127.0.0.1\t${syshostname}\n::1\t\t${syshostname}\n127.0.1.1\t${syshostname}.localdomain\t${syshostname}\" > /etc/hosts"
checkfail "?"

step "Set root password"
$ch passwd
checkfail "?"
