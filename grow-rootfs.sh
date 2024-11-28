#!/bin/bash

DEV="/dev/sda"
ROOTPART_ID=1
ROOTPART="$DEV""$ROOTPART_ID"

sudo swapoff -a
sudo umount /dev/sda4

# Remove partition 3 & 4 first
sudo parted $DEV resizepart 3 
sudo parted $DEV resizepart 4

sudo parted $DEV resizepart 1 100%
# Type under prompt: Yes, 480GB

sudo resize2fs $ROOTPART
