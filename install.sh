#!/bin/bash

# EDIT these variables
# configuration-options, edit before execution
new_lc_all=C
new_hd=/dev/sda
new_fs=ext4
new_hostname=archtest
new_bootsize=512MB
new_basepkg=(base base-devel grub vim git openssh)
new_mirror='http://mirror.selfnet.de/archlinux/$repo/os/$arch'
new_tz="Europe/Berlin"

# static variables. edit, if neccessary
EDITOR=vim
CHR=arch-chroot
mountpoint=/mnt/

# real script starts here

# partition, create fs and mount
parted $new_hd mktable msdos
parted $new_hd mkpart primary $new_fs 0% $new_bootsize
parted $new_hd mkpart primary $new_fs $new_bootsize 100%
mkfs.$new_fs -L $new_hostname-boot ${new_hd}1
mkfs.$new_fs -L $new_hostname-root ${new_hd}2
mount ${new_hd}2 $mountpoint/
mount ${new_hd}1 $mountpoint/boot

# set server to preferred mirror
echo "Server = $new_mirror" > /etc/pacman.d/mirrorlist

# base-installation according to Arch-Wiki
pacstrap $mountpoint/ ${new_basepkg[@]}
genfstab -pU $mountpoint/ >> $mountpoint/etc/fstab
echo $new_hostname > $mountpoint/etc/hostname
$CHR ln -sf /usr/share/zoneinfo/$new_tz /etc/localtime
echo $new_lc > $mountpoint/etc/locale.gen
$CHR locale-gen
echo LC_ALL=$_new_lc_all >> $mountpoint/etc/locale.conf
$CHR mkinitcpio -p linux

# if grub is installed not checked
$CHR grub-install --recheck $new_hd
$CHR grub-mkconfig -o /boot/grub/grub.cfg

# network, sshd, resolved
$CHR systemctl enable sshd systemd-networkd systemd-resolved

# assemble the network-configuration
netfile=$mountpoint/etc/systemd/network/50-main.network
echo '# Archinstall config-script defaults!' > $netfile
echo '# Please check your network-configuration! The proposed values have no logic!' >> $netfile
echo '[Match]' >> $netfile
for mac in $(ip addr | grep 'link/ether' | sed 's/  */ /g' | cut -d ' ' -f 3); do
	echo "MACAddress=$mac" >> $netfile
done
echo >> $netfile
echo >> $netfile

echo '[Network]' >> $netfile
for address in $(ip addr | grep 'inet' | sed 's/  */ /g' | cut -d ' ' -f 3); do
	echo "Address=$address" >> $netfile
done
echo >> $netfile
for gw in $(ip route | grep 'via' | cut -d ' ' -f 3); do
	echo "Gateway=$gw" >> $netfile
done
echo >> $netfile
for gw in $(ip -6 route | grep 'via' | cut -d ' ' -f 3); do
	echo "Gateway=$gw" >> $netfile
done
echo >> $netfile

for ns in $(grep 'nameserver' /etc/resolv.conf | cut -d ' ' -f 2); do
	echo "DNS=$ns" >> $netfile
done
	
$EDITOR $netfile
echo "Please write in here your root SSH-Key!" >> $mountpoint/root/.ssh/authorized_keys
$EDITOR $mountpoint/root/.ssh/authorized_keys

rm $mountpoint/etc/resolv.conf
$CHR ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

echo "NOW YOU CAN REBOOT!"
