#!/bin/bash
# mount_script.sh

# For a disk image *.bin, extracts the sector size, then, using the start
# sector of each partition, mounts the sector at a unique point in /mnt.
# Arguments: 
# $1: The name of the binary image to mount.
# $2: Whether we are mounting or unmounting partitions of this system. 
#     Syntax: "mount" or "unmount". Default option is "mount". 
#
# Passing strings with newlines and spaces necessitates quotes. 

main () { 
  IMAGE=$1

  # First, extract the sector size. A sample sector size line is given below as
  # a reference. We get the physical sector size so we know where to mount from
  # on the device.
  # Sector size (logical/physical): 512 bytes / 512 bytes
  #                                                             \1
  SECSIZE=$(fdisk -u -l ${IMAGE} | grep "Sector" | sed "s/.* \([0-9]*\) .*/\1/g")
  echo -e "Sector size: $SECSIZE\n"
  
  # Extract the listing of each partition.
  PARTLIST=$(fdisk -u -l ${IMAGE} | sed "1,9d" | tac | sed "1d" | tac)
  echo -e "List of partitions:"
  echo -e "${PARTLIST}"
  
  # Find whether the user wants to mount or unmount. Mount by default. 
  OPTION=${2-"mount"}
  echo -e "Option: $OPTION"
  
  # Execute the main command. Note the quotes. 
  processParitions "$PARTLIST" "$SECSIZE" "$IMAGE" "$OPTION" 
}

# A function that calls mount_partition(), once for each line of the partition
# table output by $(fdisk -u -l) on a disk image. 
# Arguments:
# $1: The list of partitions on this device. 
# $2: The size of the sectors on this device. 
# $3: The device name. 
# $4: Whether we are mounting or unmounting the partitions. 
processParitions () { 
  while IFS= read -r LINE; do 
    # Just echo each line back. 
    echo -e "Processing partition entry: \"${LINE}\"" 
    if [ "$4" = "mount" ] ; then 
      mountPartition "${LINE}" $2 $3 
    elif [ "$4" = "unmount" ] ; then 
      unmountParition "${LINE}"
    fi
  done <<< "$1"
}

# A function which, given a line describing a partition of a table from 
# $(fdisk -u -l), as well as a sector size, will mount the partition in 
# /mnt in a directory named as the partition name.
# Arguments:
# $1: The individual line from $(fdisk -u -l) describing this partition.
# $2: The sector size of this device.
# $3: The device name. 
# 
# A legend line and a sample output line are given for editing reference.
# Device               Boot     Start       End  Blocks  Id System
# AVOS00000336-11.bin1           2016     10079    4032  83 Linux
mountPartition () {
  LINE=$1  # The line that is an fdisk entry to mount.
  PARTNAME=$(echo -e ${LINE} | cut -d ' ' -f 1)  # First field: partition name.
  STARTSEC=$(echo -e ${LINE} | cut -d ' ' -f 2)  # Next field: starting sector.
  SECSIZE=$2  # Sector size is the second argument.
  IMAGE=$3  # Image name is the third argument.
  OFFSET=$(expr $STARTSEC \* $SECSIZE)
  DEST=/mnt/${PARTNAME} 
  mkdir -p $DEST  
  echo -e "Executing: mount -o ro,loop,offset=$OFFSET -t auto $IMAGE $DEST ..."
  mount -o ro,loop,offset=$OFFSET -t auto $IMAGE $DEST
}

# A function which, given a line describing a pritition table from the output 
# of $(fdisk -u -l), will unmount the directory created by the mountParition()
# function, then remove the directory. 
# Arguments: 
# $1: The individual line from $(fdisk -u -l) describing this partition. 
unmountParition() {
  LINE=$1  # The line that is an fdisk entry to mount.
  PARTNAME=$(echo -e ${LINE} | cut -d ' ' -f 1)  # First field: partition name.
  DEST=/mnt/$PARTNAME
  echo -e "Unmounting $DEST ..." 
  umount $DEST
  echo -e "Removing directory $DEST ..."
  rmdir $DEST 
}

main "$@" 
