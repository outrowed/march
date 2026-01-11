#!/usr/bin/bash
# Unattend Arch by Outrowed

. "$(dirname ${BASH_SOURCE[0]})"/common.sh
. "$SCRIPTDIR/config.sh"

echo "Reformatting partitions..."

# Reformat partitions

mkfs.ext4 -F -L "$IROOT_PARTITION_LABEL" -O fast_commit,metadata_csum /dev/disk/by-partlabel/"$IROOT_PARTITION_LABEL"
mkfs.ext4 -F -L "$IHOME_PARTITION_LABEL" -O fast_commit,metadata_csum /dev/disk/by-partlabel/"$IHOME_PARTITION_LABEL"