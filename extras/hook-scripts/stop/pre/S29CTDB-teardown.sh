#! /bin/bash
#non-portable - RHS-2.0 only
SMB_CONF=/etc/samba/smb.conf

CTDB_MNT=/gluster/lock
PROGNAME="ctdb"
OPTSPEC="volname:"
VOL=
# $META is the volume that will be used by CTDB as a shared filesystem.
# It is not desirable to use this volume for storing 'data' as well.
# META is set to 'all' (viz. a keyword and hence not a legal volume name)
# to prevent the script from running for volumes it was not intended.
# User needs to set META to the volume that serves CTDB lockfile.
META="all"

function sighup_samba () {
        pid=`cat /var/run/smbd.pid`
        if [ "$pid" != "" ]
        then
                kill -HUP $pid;
        else
                /etc/init.d/smb start
        fi
}

function parse_args () {
        ARGS=$(getopt -l $OPTSPEC  -name $PROGNAME $@)
        eval set -- "$ARGS"

        while true; do
            case $1 in
                --volname)
                    shift
                    VOL=$1
                ;;

                *)
                     shift
                     break
                ;;

            esac

            shift
        done
}


function remove_ctdb_options () {
        IFS=$'\n'
        GLUSTER_CTDB_CONFIG=$'# ctdb config for glusterfs\n\tclustering = yes\n\tidmap backend = tdb2\n'

        for line in $GLUSTER_CTDB_CONFIG
        do
                sed -i /"$line"/d $SMB_CONF
        done
        unset IFS
}

function remove_fstab_entry () {
	volname=$1
	mntpt=$2
	mntent="`hostname`:/$volname $mntpt glusterfs defaults,transport=tcp 0 0"
	esc_mntent=$(echo -e "$mntent" | sed 's/\//\\\//g')
	exists=`grep "$mntent" /etc/fstab`
	if [ "$exists" != " " ]
	then
		sed -i /"$esc_mntent"/d /etc/fstab
	fi
}

parse_args $@
if [ "$META" = "$VOL" ]
then
        umount "$CTDB_MNT"
        chkconfig ctdb off
	remove_fstab_entry $VOL $CTDB_MNT
        remove_ctdb_options
        sighup_samba
fi
