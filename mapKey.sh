#/bin/bash

nk_code=148
nk_buKey="/home/user/.ssh/id_rsa"
nk_passHash="d41d8cd98f00b204e9800998ecf8427e"
nk_eventFile="/dev/input/event7"
nk_archive="/backup.tar"
nk_remote="root@backup.server"

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )/$(basename $0)"
TMP_PASS=""

nk_backup(){
    sudo rm -f     $nk_archive
    sudo tar -cvf  $nk_archive  $SCRIPTPATH
    sudo tar -cvf  $nk_archive  $nk_buKey
    sudo tar rvf   $nk_archive  /home/user/.hid
    sudo tar rvf   $nk_archive  /home/user/.ssh
    sudo tar rvf   $nk_archive  /home/user/.bash_history
}

nk_encrypt(){
    echo "Encrypting with pass:$TMP_PASS"
    sudo rm -f $nk_archive.enc
    sudo openssl enc -in $nk_archive -aes-256-cbc -salt -pass pass:$TMP_PASS -out $nk_archive.enc
    sudo rm -f $nk_archive
}

nk_upload(){
    sudo scp -i $nk_buKey $nk_archive.enc $nk_remote:$nk_archive.enc
}

nk_destroy(){
    sudo rm $nk_archive.enc
    local disks=$(sudo parted -l 2>&1 | grep Disk\ / | grep -v mapper | tr ':' ' ' | cut -d ' ' -f2)
    # destroy all disks
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
 local pass=$(zenity --password --title="Typi in your password to proceed!" --timeout=10)
 passHash=$(echo $pass | md5sum | cut -d' ' -f1)
 if [ "$passHash" = "$nk_passHash" ]; then
    TMP_PASS=$pass
    nk_action
    TMP_PASS=""
 else
    echo "Wrong password!"
 fi
}

sudo evtest $nk_eventFile | grep --line-buffered -E "code\ $nk_code.*value\ 0" | while read ; do nk_trigger ; done

