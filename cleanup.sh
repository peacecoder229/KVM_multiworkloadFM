#!/bin/bash

echo "Cleaning up the machines"

virsh destroy $1 --graceful
virsh undefine $1
sudo dhclient -r $ sudo dhclient
virsh list --all
virsh net-list --name | xargs -i virsh net-dhcp-leases --network {} | cut -f 1 -d "/" | cut -f 16 -d " "| grep -v "-"


