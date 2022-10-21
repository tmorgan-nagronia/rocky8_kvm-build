#!/bin/bash
source ./settings.conf

# Warning 
echo "WARNING:    THIS SCRIPT IS GOING TO MAKE CHANGES TO THE DISKS."
echo "Infomation: This script is designed to work on unpartitioned (new) disks."

length=${#disks[@]}

echo "The following disks will be modifiyed:"

for (( i=0; i<${length}; i++ ));
do 
  echo "${disks[i]}"
done


echo "Configuring disks..."
for (( i=0; i<${length}; i++ ));
do 
    echo "   Partitioning ${disks[i]}..."
    sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF  | fdisk ${disks[i]}
    n # new partition
    p # primary partition
    1 # partion number 1
        # default,first sector
        # default, second sector
    p # print 
    w # write 
    q # finish
EOF

    echo "   Formatting ${disks[i]}..."
    sudo mkfs -t ext4 ${disks[i]}1

    mkdir -p /srv/kvm/vms/vmstore${i}/
    echo "${disks[i]}1               /srv/kvm/vms/vmstore${i}   ext4    defaults        0 0" >> /etc/fstab

done


