#!/bin/bash
#
# Huaicheng Li <lhcwhu@gmail.com>
#
# This is the first script we run after the CloudLab node is up, the goal of
# this cript is to serve as a push-button solution so that the node is
# configured properly after running this script so one can focus on the
# experiments.
#
# Put all the following configuration tasks in this script:
# - CPU related configs: disable hyperthreading, turbo boost, C-states, etc.
# - System related configs: passwordless sudo, dep packages, etc.
# - Any other customized initialization tasks (e.g., setup your home directory,
#   etc.)
#

LOGF="p.log"

function install_packages()
{
    sudo apt-get update
    # Some system tools I regularly use
    sudo apt-get install -y numactl htop sysstat linux-tools-generic linux-tools-$(uname -r) i7z

    # For QEMU/KVM
    sudo apt-get install -y qemu-kvm

    # For rocksdb
    sudo apt-get install -y libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev

    # For development
    sudo apt-get install -y cscope exuberant-ctags silversearcher-ag
    sudo apt-get install -y cmake libncurses5-dev ninja-build meson

    # For benchmarking
    sudo apt-get install -y fio

    echo "==> [$(date)] $0 done ..."
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

    echo "==> [$(date)] $0 done ..."
}

function configure_sudo_passwdless()
{
    me=$(whoami)
    STR="${me} ALL=(ALL) NOPASSWD: ALL"
    if [[ "$(sudo grep "$STR" /etc/sudoers)" == "" ]]; then
        echo "$STR" | sudo tee -a /etc/sudoers >/dev/null
    fi

    echo "==> [$(date)] $0 done ... with (me: $me)"
}

function configure_system()
{
    # sysctl changes does not need reboot to take effect, do "sysctl -p" though
    SYSCTL_CONF="/etc/sysctl.conf"
    LIMITS_CONF="/etc/security/limits.conf"
    SYSTEMD_CONF="/etc/systemd/system.conf"

    # Enlarge maximum allowed number of open files
    sudo sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65536/' $SYSTEMD_CONF

    SOFT_NOFILE_LIMIT="*         soft    nofile      500000"
    HARD_NOFILE_LIMIT="*         hard    nofile      500000"
    if [[ "$(grep "${SOFT_NOFILE_LIMIT}" $LIMITS_CONF)" == "" ]]; then
        echo "${SOFT_NOFILE_LIMIT}" | sudo tee -a $LIMITS_CONF
        echo "${HARD_NOFILE_LIMIT}" | sudo tee -a $LIMITS_CONF
    fi

    FS_FILE_MAX="fs.file-max = 2097152"
    # Increase the total number of open files system-wide
    if [[ "$(grep "^fs.file-max" $SYSCTL_CONF)" == "" ]]; then
        echo "${FS_FILE_MAX}" | sudo tee -a $SYSCTL_CONF
    fi

    # Disable swapping
    sudo swapoff -a
    if [[ "$(grep "^vm.swappiness" $SYSCTL_CONF)" == "" ]]; then
        echo "vm.swappiness=0" | sudo tee -a $SYSCTL_CONF
    else
        sudo sed -i 's/^vm.swappiness=.*/vm.swappiness=0/' $SYSCTL_CONF
    fi
    sudo sysctl -p

    # sudo passwdless
    configure_sudo_passwdless
}

# $1: "on" "off"
function toggle_cpu_turbo_boost()
{
    param=$1
    local val=0
    SYS_NO_TURBO="/sys/devices/system/cpu/intel_pstate/no_turbo"

    if [[ "$param" == "on" ]]; then
        val=0
    elif [[ "$param" == "off" ]]; then
        val=1
    else
        echo "===>Error: $0 only accepts \"on\" and \"off\" parameters"
        val=1
    fi

    echo "$val" | sudo tee -a ${SYS_NO_TURBO} >/dev/null

    echo "==> [$(date)] $0 done ... now turbo is [$param]"
}

# $1: "on", "off"
function toggle_cpu_hyper_threading()
{
    local param=$1
    local SYS_SMT_CONTROL="/sys/devices/system/cpu/smt/control"

    if [[ "$param" != "on" && "$param" != "off" ]]; then
        echo "===>Error: $0 only accepts \"on\" and \"off\" parameters"
    fi

    echo "$param" | sudo tee ${SYS_SMT_CONTROL} >/dev/null

    echo "==> [$(date)] $0 done ... now HT is [$param]"
}

# $1: "on", "off"
function toggle_cpu_cstate()
{
    param=$1
    if [[ "$param" == "on" ]]; then
        sudo killall a.out
    elif [[ "$param" == "off" ]]; then
        sudo killall a.out
        sudo nohup ./a.out 2>/dev/null &
        if [[ "$(ps -ef | grep a.out | grep -v grep)" == "" ]]; then
            echo "===> Error: CPU C-state not disabled ..."
        fi
    fi

    echo "==> [$(date)] $0 done ... now C-state is [$param]"
}

function set_performance_mode()
{
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee $governor >/dev/null
    done

    echo "==> [$(date)] $0 done ... now CPUs are in [performance] mode"
}

function configure_cpu()
{
    set_performance_mode
    toggle_cpu_cstate off
    toggle_cpu_turbo_boost on
    toggle_cpu_hyper_threading off
}

function flush_pagecache()
{
    echo 3 | sudo tee /proc/sys/vm/drop_caches
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
function main()
{
    install_packages
    configure_system
    configure_cpu

    #clone_repos
}

main > $LOGF 2>&1
