#!/usr/bin/env bash

SOURCE="${BASH_SOURCE[0]}"
cd -P "$( dirname "$SOURCE" )"
DIR="$( pwd )"

# Download the latest update file from Github
wget https://raw.githubusercontent.com/mycroft-dev/rootfs/master/home/aawadm/update.sh
if [ -f update.sh ] ; then
    if [ ! -f .last_update_md5 ] || ! md5sum -c &> /dev/null < .last_update_md5 ; then
        #Store a fingerprint of update.sh
        md5sum CheckForUpdate.sh update.sh > .last_update_md5

        # Run the update
        bash update.sh

        # Rename but keep track of it and when it was applied
        cd $DIR
        mv update.sh update.applied.$( date -Is )
    else
        # Already applied, discard -- it will be downloaded again next boot
        rm update.sh
    fi
fi