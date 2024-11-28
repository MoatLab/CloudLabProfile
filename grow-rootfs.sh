#!/bin/bash

DEV="/dev/sda"
ROOTPART_ID=1
ROOTPART="$DEV""$ROOTPART_ID"

sudo parted $DEV resizepart 1 100%
# Yes, End

sudo resize2fs $ROOTPART
