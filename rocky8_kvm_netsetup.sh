#!/bin/bash
source ./settings.conf

# Warning 
echo "WARNING: THIS SCRIPT IS GOING TO RECONFIGURE THE MACHINES NETWORK SETTINGS."
echo "         IT IS RECOMENDED THIS IS PERFORMED FROM A CONSOLE OR OOBM CONNECTION."

# Validation
    # is ${#data_vlan_ids[@]} == ${#data_vlan_names[@]}
    # Are VLAN IDs Numbers 

    # Is mgmt_vlan_mask between 8 and 30


# Confirm to user what you are going to do....

echo "Physical Interface ${physical_interface} will be configured."

echo "The following mgmt interface settings will be used:"
echo "VLANID: ${mgmt_vlan_id}"
echo "IPADDR: ${mgmt_vlan_ipaddr}"
echo "NETMASK: ${mgmt_vlan_mask}"
echo "DFGW: ${mgmt_vlan_dfgw}"
echo "DNS1: ${mgmt_vlan_dns1}"
echo "DNS2: ${mgmt_vlan_dns2}"
echo ""
echo "Data VLANS to be created:"

length=${#data_vlan_ids[@]}

for (( i=0; i<${length}; i++ ));
do 
  echo "${data_vlan_ids[i]} = ${data_vlan_names[i]}"
done

echo "========================================================"

echo "Configuring Hostname..."
nmcli general hostname ${hostname}

echo "Brining down physical interface..."
ip link set dev ${PHYSICAL} down

# Clear physical interface configuration


# Configure Physical Interface 
echo "Configuring physical interface..."
nmcli connection modify ${physical_interface} connection.autoconnect yes
nmcli connection modify ${physical_interface} ipv4.method disabled 
nmcli connection modify ${physical_interface} ipv6.method disabled 


# Configure Management Sub Interface 
echo "Configuring management sub-interface..."
nmcli con add type vlan con-name ${physical_interface}.3 ifname ${physical_interface}.3 dev ${physical_interface} id 3 


# Configure Management Bridge 
echo "Configuring management sub-interface..."
nmcli con add type bridge con-name ${physical_interface}.3_bri ifname ${physical_interface}.3_bri 
nmcli connection modify ${physical_interface}.3_bri bridge.stp yes
nmcli connection modify ${physical_interface}.3_bri autoconnect yes


nmcli connection modify ${physical_interface}.3_bri ip4 ${mgmt_vlan_ipaddr}/${mgmt_vlan_mask}
nmcli connection modify ${physical_interface}.3_bri ipv4.gateway ${mgmt_vlan_dfgw}
nmcli connection modify ${physical_interface}.3_bri ipv4.dns ${mgmt_vlan_dns1} 
nmcli connection modify ${physical_interface}.3_bri +ipv4.dns ${mgmt_vlan_dns2} 
nmcli connection modify ${physical_interface}.3_bri ipv4.method manual 

# Add VLAN Interface as Slave to the Bridge
echo "Configuring management bridge slaves..."
nmcli connection modify ${physical_interface}.3 master ${physical_interface}.3_bri slave-type bridge

# Loop through data interfaces
echo "Configuring data bridges..."
for (( i=0; i<${length}; i++ ));
do 
    echo "     Configuring ${data_vlan_names[i]} bridge..."
	# Create VLAN Interface 
    nmcli con add type vlan con-name ${physical_interface}.${data_vlan_ids[i]} ifname ${physical_interface}.${data_vlan_ids[i]} dev ${physical_interface} id ${data_vlan_ids[i]}

    # Create VLAN Bridge 
    nmcli con add type bridge con-name ${physical_interface}.${data_vlan_ids[i]}_bri ifname ${physical_interface}.${data_vlan_ids[i]}_bri 
    nmcli connection modify ${physical_interface}.${data_vlan_ids[i]}_bri bridge.stp yes
    nmcli connection modify ${physical_interface}.${data_vlan_ids[i]}_bri autoconnect yes
    nmcli connection modify ${physical_interface}.${data_vlan_ids[i]}_bri ipv4.method disabled 
    nmcli connection modify ${physical_interface}.${data_vlan_ids[i]}_bri ipv6.method disabled

    # Add VLAN Interface as Slave to the Bridge
    nmcli connection modify ${physical_interface}.${data_vlan_ids[i]} master ${physical_interface}.${data_vlan_ids[i]}_bri slave-type bridge

    # https://superuser.com/questions/990855/configure-firewalld-to-allow-bridged-virtual-machine-network-access#995272
    #firewall-cmd --permanent --direct --passthrough ipv4 -I FORWARD -i bridge0 -j ACCEPT
    #firewall-cmd --permanent --direct --passthrough ipv4 -I FORWARD -o bridge0 -j ACCEPT
    #firewall-cmd --reload

done
	
echo "Brining up physical interface..."
ip link set dev ${PHYSICAL} up

# Wait for the network to settle down
echo "Waiting for network (5mins)..."
sleep 5m 


echo "Installing kvm..."
./rocky8_kvm_install.sh

## Review https://linuxconfig.org/how-to-use-bridged-networking-with-libvirt-and-kvm (Disabling netfilter for the bridge)

echo "Configuring bridge networks in kvm..."
for (( i=0; i<${length}; i++ ));
do 

    cat <<EOF > ${data_vlan_names[i]}.xml
<network>
    <name>${data_vlan_names[i]}</name>
    <forward mode="bridge" />
    <bridge name="${physical_interface}.${data_vlan_ids[i]}_bri" />
</network>
EOF

    sudo virsh net-define ${data_vlan_names[i]}.xml

    sudo virsh net-start ${data_vlan_names[i]}
    sudo virsh net-autostart ${data_vlan_names[i]}

done



cat <<EOF > /etc/sysctl.d/99-netfilter-bridge.conf
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
EOF

modprobe br_netfilter

echo "br_netfilter" > vi /etc/modules-load.d/br_netfilter.conf

reboot