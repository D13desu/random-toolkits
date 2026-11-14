lin_check_storage() {
    lin_header 'Storage, mounts, and inodes'
    lin_section 'Filesystems'
    df -hT 2>/dev/null || df -h
    lin_section 'Inode usage'
    df -i 2>/dev/null || lin_warn 'Inode reporting unavailable.'
    if lin_has lsblk; then
        lin_section 'Block devices'
        lsblk -o NAME,TYPE,FSTYPE,SIZE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS 2>/dev/null || lsblk
    fi
}
