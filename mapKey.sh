#!/bin/bash

nk_code=148
nk_buKey="/home/user/.ssh/id_rsa"
nk_passHash="d41d8cd98f00b204e9800998ecf8427e"
nk_eventFile="/dev/input/event7"
nk_archive="/backup.tar"
nk_remote="root@backup.server"
nk_backupDisc="/dev/sdc"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )/$(basename $0)"
TMP_PASS=""

rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
        exit $?
    fi
}

nk_backup(){
    rm -f     $nk_archive
    tar -cvf  $nk_archive  $SCRIPTPATH
    tar -cvf  $nk_archive  $nk_buKey
    tar rvf   $nk_archive  /home/user/.hid
    tar rvf   $nk_archive  /home/user/.ssh
    tar rvf   $nk_archive  /home/user/.bash_history
}

nk_encrypt(){
    rm -f $nk_archive.enc
    openssl enc -in $nk_archive -aes-256-cbc -salt -pass pass:$TMP_PASS -out $nk_archive.enc
    rm -f $nk_archive
}

nk_upload(){
    local firstPartition=$(fdisk -l $nk_backupDisc | grep '^/dev' | cut -d' ' -f1 | head -n 1)
    local backupDir="/mnt/backup/plan-b-$(date +%Y-%m-%d-%H-%M-%S)"
    umount $nk_backupDisc* 2>&1 > /dev/null
    rm -rf /mnt/backup
    mkdir  /mnt/backup
    mount $firstPartition /mnt/backup
    mkdir $backupDir 2>&1 > /dev/null
    cp $nk_archive.enc $backupDir
    umount $nk_backupDisc* 2>&1 > /dev/null
    rm -rf /mnt/backup
    scp -i $nk_buKey $nk_archive.enc $nk_remote:$nk_archive.enc
}

nk_destroy(){
    rm $nk_archive.enc
    local disks=$( parted -l 2>&1 | grep Disk\ / | grep -v mapper | grep -v $nk_backupDisc | tr ':' ' ' | cut -d ' ' -f2)
    for disk in $disks; do
        #$(shred $disk) &
        $( sleep 5 ) &
    done
    wait
}

nk_reboot(){
    sleep 1
#    sudo reboot
}

nk_action(){

    (
        echo "10"
        echo "# Backing up" && nk_backup
        echo "20"
        echo "# Encrypting" && nk_encrypt
        echo "30"
        echo "# Uploading " && nk_upload
        echo "40"
        echo "# Destroying" && nk_destroy
        echo "75"
        echo "# Rebooting " && nk_reboot
        echo "100"
    ) |
    zenity --progress \
    --title="Backup and destroy!" \
    --text="Preparing ..." \
    --percentage=0
}

nk_trigger(){
 local pass=$(zenity --password --title="Type in your password to proceed!" --timeout=10)
 passHash=$(echo $pass | md5sum | cut -d' ' -f1)
 if [ "$passHash" = "$nk_passHash" ]; then
    TMP_PASS=$pass
    nk_action
    TMP_PASS=""
 else
    echo "Wrong password!"
 fi
}

rootcheck "${@}"
evtest $nk_eventFile | grep --line-buffered -E "code\ $nk_code.*value\ 0" | while read ; do nk_trigger ; done

