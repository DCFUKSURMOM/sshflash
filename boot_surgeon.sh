#!/bin/bash

# We use a public/private keypair to authenticate. 
# Surgeon uses the 169.254.8.X subnet to differentiate itself from
# a fully booted system for safety purposes.
SSH="ssh root@169.254.8.1"

show_warning () {
  echo "Surgeon boot utility, modified from the sshflash script to keep it simple"
  echo "This utility boots the surgeon environment and mounts useful partitions on your device"
  echo "Unlike the other scripts, this one does not flash anything. It is solely for poking around an installed system without it being booted"
  echo "This is great if you want to modify files on the stock operating system, but it also works with retroleap"
  echo
  echo "Improper use of surgeon can potentially mess up the OS on your device, requiring a reflash"
  echo "This is experimantal and a work in progress, proceed at your own risk."
  echo
  echo "Please power off your leapster, hold the L + R shoulder buttons (LeapsterGS), "
  echo "or right arrow + home buttons (LeapPad2), and then press power."
  echo "You should see a screen with a green background."

  read -p "Press enter when you're ready to continue."
}

show_machinelist () {
  echo "What type of system would you like to boot surgeon on?"
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

part_detect () {
  # Probe for filesystem partition locations, they can vary based on kernel version + presence of NOR flash drivers.
  # TODO: Make the escaping less yucky...
  KERNEL_PARTITION=`${SSH} "awk -e '\\$4 ~ /\"Kernel\"/ {print \"/dev/\" substr(\\$1, 1, length(\\$1)-1)}' /proc/mtd"`
  RFS_PARTITION=`${SSH} "awk -e '\\$4 ~ /\"RFS\"/ {print \"/dev/\" substr(\\$1, 1, length(\\$1)-1)}' /proc/mtd"`
  BULK_PARTITION=`${SSH} "awk -e '\\$4 ~ /\"Bulk\"/ {print \"/dev/\" substr(\\$1, 1, length(\\$1)-1)}' /proc/mtd"`
  echo "Kernel partition=$KERNEL_PARTITION RFS Partition=$RFS_PARTITION Bulk Partition=$BULK_PARTITION"
}

surgeon_lf1k_2k () {
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
  part_detect
  ${SSH} "ubiattach /dev/ubi_ctrl -p $RFS_PARTITION"
  ${SSH} "mount -t ubifs /dev/ubi0_0 -o rw /mnt/root"
  ${SSH} "ubiattach /dev/ubi_ctrl -p $BULK_PARTITION"
  ${SSH} "mkdir -p /mnt/bulk" #in case of old surgeon image without bulk directory
  ${SSH} "mount -t ubifs /dev/ubi1_0 -o rw /mnt/bulk"
  ${SSH} "echo rootfs partition mounted at /mnt/root, bulk/roms partition mounted at /mnt/bulk"
  echo "SSHing into your device..."
  ${SSH}
}

surgeon_lf3k () {
  prefix=$1
  boot_surgeon ${prefix}surgeon_zImage superhigh
  # For the first ssh command, skip hostkey checking to avoid prompting the user.
  ${SSH} -o "StrictHostKeyChecking no" 'test'
  sleep 3
  part_detect
  ${SSH} "ubiattach /dev/ubi_ctrl -p $RFS_PARTITION"
  ${SSH} "mount -t ubifs /dev/ubi0_0 -o rw /mnt/root"
  ${SSH} "ubiattach /dev/ubi_ctrl -p $BULK_PARTITION"
  ${SSH} "mkdir -p /mnt/bulk" #in case of old surgeon image without bulk directory
  ${SSH} "mount -t ubifs /dev/ubi1_0 -o rw /mnt/bulk"
  ${SSH} "echo rootfs partition mounted at /mnt/root, bulk/roms partition mounted at /mnt/bulk"
  echo "SSHing into your device..."
  ${SSH} 
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
	surgeon_lf3k $prefix
else
        surgeon_lf1k_2k $prefix
fi
