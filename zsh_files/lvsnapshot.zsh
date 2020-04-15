#!/usr/bin/env zsh

: ${DEFAULT_VG="vg0"}

# lvm-detectfs [volume_name] (VG (default: DEFAULT_VG))
# 
#   # Assuming DEFAULT_VG="vg0"
#   $ lvm-detectfs root    # detect filesystem of vg0/root
#   ext4
#   $ lvm-detectfs cache   # detect filesystem of vg0/cache
#   xfs
#
lvm-detectfs() {
    if (( $# < 1 )); then
        msg yellow "Usage: lvm-detectfs [volume_name] (VG (default: $DEFAULT_VG))"
        msg
        return 1
    fi
    local lv_vol="$1" lv_vg="$DEFAULT_VG" res res_len

    (( $# > 1 )) && lv_vg="$2"

    res=$(blkid | grep "/${lv_vg}-${lv_vol}:" | sed -r 's/.*TYPE="(.*)"/\1/')
    res_len=$(wc -c <<< "$res")
    res_len=$(( res_len - 1 ))

    if (( res_len == 0 )); then
        >&2 msg red " [!!!] [lvm-detectfs] Could not detect FS for LV ${lv_vg}/${lv_vol}\n"
        return 1
    fi
    echo "$res"
}

# lvm-exists [volume_name]
# quickly check if a given logical volume exists
#
#   $ lvm-exists somelv && echo "somelv exists" || echo "somelv does not exist"
#
lvm-exists() {
    lvs | grep -Eq "^ +$1 "
}

# snapshot [volume_name] (VG (default: DEFAULT_VG)) (snap_name)
# Create an LVM snapshot of volume_name at volume_name_snapDDmonthYYYY_HHMM
#
#  - Snapshots volume_name into volume_name_snapDDmonthYYYY_HHMM
#
#  - Disables activation lock on the snapshot so that it's activated on boot
#
#  - Activates the snapshot volume so it can be mounted immediately
#
#  - If the volume used the XFS filesystem, will clear the journal and reset the FS UUID 
#    for the snapshot volume (otherwise there'll be a UUID conflict and it won't mount)
#
snapshot() {
    if (( $# < 1 )); then
        msg yellow "Usage: snapshot [volume_name] (VG (default: $DEFAULT_VG)) (snap_name)"
        msg "Examples:"
        msg cyan "    snapshot hive2"
        msg cyan "    snapshot somelv vg0"
        msg cyan "    snapshot otherlv vg0 otherlv_snapshot1"
        msg
        return 1
    fi

    local snap_vol="$1" snap_vg="$DEFAULT_VG" snap_date="$(date +'%d%b%Y_%H%M' | tr '[:upper:]' '[:lower:]')" snap_name snap_src
    snap_name="${snap_vol}_snap${snap_date}"

    (( $# > 1 )) && snap_vg="$2"
    (( $# > 2 )) && snap_name="$3"

    snap_src="${snap_vg}/${snap_vol}"

    if ! lvm-exists "${snap_vol}"; then
        >&2 msg red "ERROR: Volume ${snap_vol} does not exist.\n"
        >&2 msg red "Cannot snapshot non-existent volume. Run 'lvs' to view all volumes available\n"
        return 1
    fi

    msg green " >> Snapshotting ${snap_src} as ${snap_name}"

    if lvm-exists "$snap_name"; then
        >&2 msg red "ERROR: '${snap_name}' already exists!"
        return 1
    fi

    msg green "\n >> Disabling activation lock for ${snap_src} \n"
    lvchange -k n "${snap_src}"

    msg green "\n >> Activating LVM volume ${snap_src} \n"
    lvchange -a y "${snap_src}"
    sleep 1

    msg green "\n >> Creating snapshot ${snap_name} from ${snap_src}"
    lvcreate -s -n "$snap_name" "$snap_src"
    sleep 1

    msg green "\n >> Disabling activation lock for ${snap_vg}/${snap_name} \n"
    lvchange -k n "${snap_vg}/${snap_name}"

    msg green "\n >> Activating LVM volume ${snap_vg}/${snap_name} \n"
    lvchange -a y "${snap_vg}/${snap_name}"

    sleep 3

    fix-xfs-snapshot "$snap_name" "$snap_vg"

    msg bold green " +++ FINISHED +++ \n"

}

# Used by 'snapshot' and 'restore-snapshot' to clear journal + reset UUID for XFS volumes
# after being cloned
fix-xfs-snapshot() {
    if (( $# < 1 )); then
        msg yellow "Usage: fix-xfs-snapshot [volume_name] (VG (default: $DEFAULT_VG))"
        msg "Examples:"
        msg cyan "    fix-xfs-snapshot hive2"
        msg cyan "    fix-xfs-snapshot somevg vg0"
        msg
        return 1
    fi

    local snap_vol="$1" snap_vg="$DEFAULT_VG"
    (( $# > 1 )) && snap_vg="$2"

    msg green "\n >> Checking for XFS filesystem ... \n"
    orig_fs=$(lvm-detectfs "$snap_vol" "$snap_vg")

    snap_dev="/dev/${snap_vg}/${snap_vol}"

    if (( $? != 0 )); then
        msg bold red "Could not detect filesystem - if this was an XFS volume, you'll need to repair the snapshot manually:\n"
        msg cyan "    xfs_repair -L $snap_dev"
        msg cyan "    xfs_admin -U $(uuidgen) $snap_dev"
        msg red "Exiting...\n"
        return 1
    fi

    if [[ "$orig_fs" == "xfs" ]] || [[ "$orig_fs" == "XFS" ]]; then
        msg yellow " [!!!] Detected XFS filesystem on source volume. Clearing XFS journal and re-generating UUID for $snap_dev ... \n"

        msg cyan "\n >> Clearing XFS journal ...\n"
        xfs_repair -L "$snap_dev" > /dev/null

        msg cyan "\n >> Re-generating filesystem UUID ...\n"
        xfs_admin -U $(uuidgen) "$snap_dev"

        msg green "\n [+++] Finished repairing XFS filesystem for snapshot volume $snap_dev \n"
    else
        msg green "\n [+++] Source volume was not an XFS filesystem, no need to repair the snapshot :)\n"
    fi
}


# restore-snapshot [snapshot_name] [output_name] (VG (default: DEFAULT_VG))
# Restore an LVM snapshot 'snapshot_name' to the volume 'output_name'
#
#  - Ensures both the snapshot and the output volume are unmounted
#  
#  - Removes the volume 'output_name' if it already exists (warns you before doing so)
# 
#  - Snapshots 'snapshot_name' into 'volume_name'
#
#  - Disables activation lock on 'volume_name' so that it's activated on boot
#
#  - Activates the 'volume_name' volume so it can be mounted immediately
#
#  - If the volume used the XFS filesystem, will clear the journal and reset the FS UUID 
#    for the cloned volume (otherwise there'll be a UUID conflict and it won't mount)
#
#  - Scans /etc/fstab for any 'volume_name' mounts.
#       - If there are any mounts defined, will auto-mount 'volume_name'
#
restore-snapshot() {

    if (( $# < 2 )); then
        msg yellow "Usage: restore-snapshot [snapshot_name] [output_name] (VG (default: $DEFAULT_VG))"
        msg "Examples:"
        msg cyan "    restore-snapshot hive2_snap15apr2020_0340 hive2"
        msg cyan "    restore-snapshot hive2shm_snap13apr2020_1529 hive2shm nvraid"
        msg
        return 1
    fi

    local snap_vol="$1" snap_out="$2" snap_vg="$DEFAULT_VG" snap_src snap_dst snap_dev out_dev mount_list
    local out_dev_vg unmounted_snap=0 unmounted_out=0

    (( $# > 2 )) && snap_vg="$3"

    snap_src="${snap_vg}/${snap_vol}"
    snap_dst="${snap_vg}/${snap_out}"

    snap_dev="/dev/mapper/${snap_vg}-${snap_vol}"
    out_dev="/dev/mapper/${snap_vg}-${snap_out}"
    out_dev_vg="/dev/${snap_vg}/${snap_out}"

    msg
    msg green " >>> Restoring snapshot ${snap_vol} to ${snap_out} ...\n"

    if ! lvm-exists "${snap_vol}"; then
        msg red "ERROR: Snapshot volume ${snap_vol} does not exist.\n"
        msg red "Cannot restore non-existent snapshot. Run 'lvs' to view all volumes available\n"
        return 1
    fi

    msg green " [...] Checking if ${snap_dev} is mounted ..."

    if mount | grep -Eq "^${snap_dev} "; then
        msg red "WARNING: ${snap_vol} is currently mounted. Will auto-unmount ${snap_dev} for safety."
        umount -v "${snap_dev}"
        if (( $? != 0 )); then
            msg bold red "ERROR: Cannot unmount ${snap_dev} - exiting.\n"
            return 1
        fi
        msg green " [+++] Unmounted ${snap_dev}"
        unmounted_snap=1
    fi

    msg green " [...] Checking if ${out_dev} is mounted ..."
    if mount | grep -Eq "^${out_dev} "; then
        msg red "WARNING: ${snap_out} is currently mounted. Will auto-unmount ${out_dev} for safety."
        umount -v "${out_dev}"
        if (( $? != 0 )); then
            msg bold red "ERROR: Cannot unmount ${out_dev} - exiting.\n"
            return 1
        fi
        msg green " [+++] Unmounted ${out_dev}"
        unmounted_out=1
    fi


    if lvm-exists "${snap_out}"; then
        msg red " [!!!] WARNING: The LVM volume '${snap_out}' already exists. We'll need to delete it before we can replace it with the snapshot.\n"

        if yesno "${YELLOW}Do you want to continue with deleting the volume '${snap_out}'?"; then
            msg yellow " [...] Removing volume '${snap_dst}'\n"
            lvremove "${snap_dst}"

            if (( $? != 0 )); then
                msg bold red "ERROR: Cannot remove ${snap_out} - exiting.\n"
                return 1
            fi
            msg green "\n [+++] Volume ${snap_out} was removed."
        else
            msg red "You've said no. Cancelling snapshot restore."
            (( unmounted_snap == 1 )) && msg green " >> Remounting snapshot volume $snap_dev" && mount -v "$snap_dev"
            (( unmounted_out == 1 )) && msg green " >> Remounting restore volume $out_dev" && mount -v "$out_dev"
            msg yellow "\nExiting...\n"
            return 1

        fi
    fi

    msg green " >>> Snapshotting ${snap_src} into ${snap_dst} ..."

    lvcreate -s -n "$snap_out" "$snap_src"

    sleep 1
    msg green "\n >> Disabling activation lock for ${snap_dst} \n"
    lvchange -k n "${snap_dst}"

    msg green "\n >> Activating LVM volume ${snap_dst} \n"
    lvchange -a y "${snap_dst}"
    sleep 3

    fix-xfs-snapshot "$snap_out" "$snap_vg"

    if grep -Eq "^${out_dev} " /etc/fstab; then
        msg green "\n >>> Re-mounting ${out_dev} \n"
        mount -v "${out_dev}"
        msg green " [+++] Remounted ${out_dev} \n"

    elif grep -Eq "^${out_dev_vg} " /etc/fstab; then
        msg green "\n >>> Re-mounting ${out_dev_vg} \n"
        mount -v "${out_dev_vg}"
        msg green " [+++] Remounted ${out_dev_vg} \n"
    else
        msg yellow " [---] Didn't find ${out_dev} or ${out_dev_vg} in /etc/fstab - not auto re-mounting.\n"
    fi

    msg bold green " +++ FINISHED +++ \n"

}
