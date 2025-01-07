#!/bin/bash

# We use a public/private keypair to authenticate. 
# Surgeon uses the 169.254.8.X subnet to differentiate itself from
# a fully booted system for safety purposes.
SSH="ssh root@169.254.8.1"

show_warning () {
  echo "Leapster kernel flash utility - installs a custom kernel on your device!"
  echo "modified from the regular sshflash script by DCFUKSURMOM"
  echo
  echo "WARNING! This utility will ERASE the stock kernel"
  echo "The device can be no longer be restored to stock firmware using"
  echo "the LeapFrog Connect app, because they shut it down."
  echo "We are working on collecting stock os images and converting them"
  echo "to work with sshflash, so that they can be restored"
  echo "Stock images have been found for the following devices: Leapster GS"
  echo "Note that flashing your kernel will likely"
  echo "VOID YOUR WARRANTY! Proceed at your own risk."
  echo
  echo "Please power off your leapster, hold the L + R shoulder buttons (LeapsterGS), "
  echo "or right arrow + home buttons (LeapPad2), and then press power."
  echo "You should see a screen with a green background and a picture of your device"
  echo "connecting to a computer"

  read -p "Press enter when you're ready to continue."
}

show_machinelist () {
  echo "----------------------------------------------------------------"
  echo "What type of system would you like to flash?"
  echo
  echo "1. LF1000-Didj (Didj with EmeraldBoot)"
  echo "2. LF1000-Leappad1 (Leappad 1)"
  echo "3. LF1000 (Leapster Explorer)"
  echo "4. LF2000 (Leapster GS, LeapPad 2, LeapPad Ultra XDI)"
  echo "5. [EXPERIMENTAL] LF2000 w/ Realtime Kernel (Leapster GS, LeapPad 2, LeapPad Ultra XDI)"
  echo "6. [EXPERIMENTAL] LF2000 w/ Overclocked Realtime Kernel (Leapster GS, LeapPad 2, LeapPad Ultra XDI)"
  echo "7. LF3000 (LeapPad 3, LeapPad Platinum)"
}

boot_surgeon () {
  surgeon_path=$1
  memloc=$2
  echo "Booting the Surgeon environment..."
  python2 make_cbf.py $memloc $surgeon_path surgeon_tmp.cbf
  sudo python2 boot_surgeon.py surgeon_tmp.cbf
  echo -n "Done! Waiting for Surgeon to come up..."
  rm surgeon_tmp.cbf
  sleep 15
  echo "Done!"
}

nand_part_detect () {
  # Probe for filesystem partition locations, they can vary based on kernel version + presence of NOR flash drivers.
  # TODO: Make the escaping less yucky...
  KERNEL_PARTITION=`${SSH} "awk -e '\\$4 ~ /\"Kernel\"/ {print \"/dev/\" substr(\\$1, 1, length(\\$1)-1)}' /proc/mtd"`
  echo "Detected Kernel partition=$KERNEL_PARTITION"
}

nand_flash_kernel () {
  kernel_path=$1
  echo -n "Flashing the kernel..."
  ${SSH} "/usr/sbin/flash_erase $KERNEL_PARTITION 0 0"
  cat $kernel_path | ${SSH} "/usr/sbin/nandwrite -p $KERNEL_PARTITION -"
  echo "Done flashing the kernel!"
}

flash_nand () {
  prefix=$1
  if [[ $prefix == lf1000_* ]]; then
	  memloc="high"
	  kernel="zImage_tmp.cbf"
	  python2 make_cbf.py $memloc ${prefix}zImage $kernel
  else
	  memloc="superhigh"
	  kernel=${prefix}uImage
  fi
  boot_surgeon ${prefix}surgeon_zImage $memloc
  # For the first ssh command, skip hostkey checking to avoid prompting the user.
  ${SSH} -o "StrictHostKeyChecking no" 'test'
  nand_part_detect
  nand_flash_kernel $kernel
  echo "Done! Rebooting the host."
  ${SSH} '/sbin/reboot'
}

mmc_flash_kernel () {
  kernel_path=$1
  echo -n "Flashing the kernel..."
  # TODO: This directory structure should be included in surgeon images.
  ${SSH} "mkdir /mnt/boot"
  # TODO: This assumes a specific partition layout - not sure if this is the case for all devices?
  ${SSH} "mount /dev/mmcblk0p2 /mnt/boot"
  cat $kernel_path | ${SSH} "cat - > /mnt/boot/uImage"
  ${SSH} "umount /dev/mmcblk0p2"
  echo "Done flashing the kernel!"
}

flash_mmc () {
  prefix=$1
  boot_surgeon ${prefix}surgeon_zImage superhigh
  # For the first ssh command, skip hostkey checking to avoid prompting the user.
  ${SSH} -o "StrictHostKeyChecking no" 'test'
  mmc_flash_kernel ${prefix}uImage
  echo "Done! Rebooting the host."
  sleep 3
  ${SSH} '/sbin/reboot'
}

show_warning
prefix=$1
if [ -z "$prefix" ]
then
  show_machinelist
  read -p "Enter choice (1 - 7)" choice
  case $choice in
    1) prefix="lf1000_didj_" ;;
    2) prefix="lf1000_leappad_" ;;
    3) prefix="lf1000_" ;;
    4) prefix="lf2000_" ;;
    5) prefix="lf2000_rt_" ;;
    6) prefix="lf2000_oc_" ;;
    7) prefix="lf3000_" ;;
    *) echo -e "Unknown choice!" && sleep 2
  esac
fi

if [ $prefix == "lf3000_" ]; then
	flash_mmc $prefix
else
        flash_nand $prefix
fi
