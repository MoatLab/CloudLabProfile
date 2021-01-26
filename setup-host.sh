#!/bin/bash

function install_packages()
{
    sudo apt update
    # Some system tools I regularly use
    sudo apt install -y numactl htop sysstat linux-tools-generic linux-tools-$(uname -r)

    # For QEMU
    sudo apt install -y qemu-kvm

    # For rocksdb
    sudo apt install -y libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev

    # For kernel development

}

function clone_repos()
{
    mkdir -p ~/git
    cd ~/git
    # linux
    git clone https://github.com/torvalds/linux.git
    # qemu
    git clone https://github.com/qemu/qemu.git
    # rocksdb
    git clone https://github.com/facebook/rocksdb.git fb-rocksdb
}

function configure_system()
{
    #-------------------------------------------------------------------------------
    # Configurations for RocksDB
    # Install rocksdb dependencies
    # Enlarge maximum allowed number of open files
    sudo sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65536/' /etc/systemd/system.conf

    echo "*         hard    nofile      500000" | sudo tee -a /etc/security/limits.conf
    echo "*         soft    nofile      500000" | sudo tee -a /etc/security/limits.conf
    # Increase the total number of open files system-wide
    echo 'fs.file-max = 2097152'  | sudo tee -a /etc/sysctl.conf
    sysctl -p
}

# $1: "on" "off"
function toggle_cpu_turbo_boost()
{
    param=$1
    local val=0
    SYS_NO_TURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"

    if [[ $param == "on" ]]; then
        val=0
    elif [[ $param == "off" ]]; then
        val=1
    else
        echo "===>Error: $0 only accepts \"on\" and \"off\" parameters"
        val=1
    fi

    echo $val | sudo tee -a ${SYS_NO_TURBO} >/dev/null
}

# $1: "on", "off"
function toggle_cpu_hyper_threading()
{
    param=$1
    SYS_NO_TURBO="/sys/devices/system/cpu/smt/control"

    if [[ $param != "on" && $param != "off" ]]; then
        echo "===>Error: $0 only accepts \"on\" and \"off\" parameters"
    fi

    echo $param | sudo tee ${SYS_SMT_CONTROL} >/dev/null
}

# $1: "on", "off"
function toggle_cpu_cstate()
{
    param=$1
    if [[ $param == "on" ]]; then
        sudo killall a.out
    elif [[ $param == "off" ]]; then
        sudo killall a.out
        sudo nohup ./a.out 2>/dev/null &
        if [[ $(ps -ef | grep a.out | grep -v grep) == "" ]]; then
            echo "===> Error: CPU C-state not disabled ..."
        fi
    fi
}

function set_performance_mode()
{
    echo "===> Placing CPUs in performance mode ..."
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee $governor >/dev/null
    done
}

function configure_cpu()
{
    set_performance_mode
    toggle_cpu_cstate off
    toggle_cpu_hyper_threading off
    #toggle_cpu_turbo_boost off
}

function flush_pagecache()
{
    echo 3 | sudo tee /proc/sys/vm/drop_caches
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
install_packages
configure_system
configure_cpu
