#!/bin/bash

sudo apt update
echo "This has been done on CloudLab initialization!" > ~/proof.txt
sudo apt install -y numactl htop sysstat
