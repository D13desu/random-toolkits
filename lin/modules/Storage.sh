lin_check_storage() {
    lin_header 'Storage, mounts, and inodes'
    printf 'Filesystems:\n'
    df -hT 2>/dev/null || df -h
    printf '\nInode usage:\n'
    df -i 2>/dev/null || lin_warn 'Inode reporting unavailable.'
    if lin_has lsblk; then
        printf '\nBlock devices:\n'
        lsblk -o NAME,TYPE,FSTYPE,SIZE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS 2>/dev/null || lsblk
    fi
}
