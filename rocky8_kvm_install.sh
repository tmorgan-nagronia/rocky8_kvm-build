#!/bin/bash

dnf -y update 

dnf -y install @virt virt-top libguestfs-tools virt-install 

systemctl enable --now libvirtd

mkdir -p /srv/kvm/iso
mkdir -p /srv/kvm/vms
mkdir -p /srv/kvm/templates

#<pool type="dir">
#  <name>templates</name>
#  <target>
#    <path>/srv/kvm/templates</path>
#  </target>
#</pool>



# Allow VNC Traffic 

firewall-cmd --add-port=5900-5999/tcp --permanent
firewall-cmd --reload 


curl https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.0-x86_64-minimal.iso -o /srv/kvm/iso/Rocky-9.0-x86_64-minimal.iso
curl https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-8.6-x86_64-minimal.iso -o /srv/kvm/iso/Rocky-8.6-x86_64-minimal.iso 
curl http://mirror.as29550.net/mirror.centos.org/7.9.2009/isos/x86_64/CentOS-7-x86_64-Minimal-2207-02.iso -o /srv/kvm/iso/CentOS-7-x86_64-Minimal-2207-02.iso
