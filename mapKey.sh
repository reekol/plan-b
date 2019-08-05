#!/bin/bash

trap "kill 0" EXIT

nk_code=148
nk_buKey="/home/user/.ssh/id_rsa"
nk_passHash="d41d8cd98f00b204e9800998ecf8427e"
nk_eventFile="/dev/input/event7"
nk_archive="/backup.tar"
nk_remote="root@backup.server"
nk_backupDisc="/dev/sdc"
nk_inputMsg="Type in your password to proceed!"


SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )/$(basename $0)"
TMP_PASS=""

rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"
        exit $?
    fi
}

nk_selfExtracting(){

local basename1=$(basename $1)
cat > $2 <<ARCHIVE_FILE
#!/bin/bash

rootcheck () {
    if [ \$(id -u) != "0" ]
    then
        sudo "\$0" "\$@"
        exit \$?
    fi
}

rootcheck

echo -n "$nk_inputMsg"
read -s tpass
tail -n+\$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' \$0) \$0 > $basename1 && \\
openssl enc -in $basename1 -aes-256-cbc -d -salt -pass pass:\$tpass -out $(basename $nk_archive)
rm $basename1
exit 0

__ARCHIVE_BELOW__
ARCHIVE_FILE
    cat $1 >> $2 && chmod +x $2
}

nk_backup(){
    rm -f     $nk_archive
    tar -cvf  $nk_archive  $SCRIPTPATH
    tar -cvf  $nk_archive  $nk_buKey
    tar rvf   $nk_archive  /home/user/.ssh
    tar rvf   $nk_archive  /home/user/.bash_history
    tar rvf   $nk_archive  /home/user/.bashrc
    tar rvf   $nk_archive  /home/user/.hid
}

nk_encrypt(){
    rm -f $nk_archive.enc
    openssl enc -in $nk_archive -aes-256-cbc -salt -pass pass:$TMP_PASS -out $nk_archive.enc
    nk_selfExtracting $nk_archive.enc $nk_archive.sh
}

nk_upload(){
     local firstPartition=$(fdisk -l $nk_backupDisc | grep '^/dev' | cut -d' ' -f1 | head -n 1)
     local backupDir="/mnt/backup/plan-b-$(date +%Y-%m-%d-%H-%M-%S)"
     umount $nk_backupDisc* 2>&1 > /dev/null
     rm -rf /mnt/backup
     mkdir  /mnt/backup
     mount $firstPartition /mnt/backup
     mkdir $backupDir 2>&1 > /dev/null
     cp -rp $nk_archive.sh $backupDir
     umount $nk_backupDisc* 2>&1 > /dev/null
     rm -rf /mnt/backup
#    scp -i $nk_buKey $nk_archive.sh $nk_remote:$nk_archive.sh
     rm -f $nk_archive
     rm -f $nk_archive.enc
     rm -f $nk_archive.sh
}

nk_destroy(){
    local disks=$( parted -l 2>&1 | grep Disk\ / | grep -v mapper | grep -v $nk_backupDisc | tr ':' ' ' | cut -d ' ' -f2)
    for disk in $disks; do
#        $(shred $disk) &
        $( sleep 0 ) &
    done
    wait
}

nk_reboot(){
CHOICE1=$(zenity --list --height=190 --title="Final step." --text="Options" --radiolist --column=">" --column="Next action" \
    TRUE  "Shutdown" \
    FALSE "Restart" \
    FALSE "Destroy")

case $CHOICE1 in
    "Shutdown" ) echo "shutdown..."  && shutdown -h now;;
    "Restart"  ) echo "restart..."   && reboot;;
    "Destroy"  ) echo "destroy..."   && nk_destroy;;
esac
}

nk_action(){

    (
        echo "10"
        echo "# Backing up" && nk_backup
        echo "40"
        echo "# Encrypting" && nk_encrypt
        echo "70"
        echo "# Uploading " && nk_upload
        echo "90"
        echo "# Rebooting " && nk_reboot
        echo "100"
    ) |
    zenity --progress --auto-close \
    --title="Backup and destroy!" \
    --text="Preparing ..." \
    --percentage=0
}

nk_trigger(){
 local pass=$(zenity --password --title="$nk_inputMsg" --timeout=10)
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

