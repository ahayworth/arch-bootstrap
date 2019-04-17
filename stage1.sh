#!/bin/bash -x

function network() {
  ping -c 1 -w 1 8.8.8.8 2>&1 >/dev/null || wifi-menu
  pacman -Sy
  timedatectl set-ntp true
}

function filesystems() {
  parted -s /dev/nvme0n1 mklabel gpt mkpart primary fat32 1MiB 551MiB name 1 boot set 1 esp on mkpart primary ext4 551MiB 100% name 2 root
  mkfs.fat /dev/nvme0n1p1
  mkfs.ext4 /dev/nvme0n1p2
  mount /dev/nvme0n1p2 /mnt
  mkdir /mnt/boot
  mount /dev/nvme0n1p1 /mnt/boot
  fallocate -l 1G /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap -L swap /mnt/swapfile
  swapon /mnt/swapfile
}

function mirrors() {
  pacman -S --noconfirm pacman-contrib
  curl -s 'https://www.archlinux.org/mirrorlist/?country=US&ip_version=4&use_mirror_status=on' | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist
}

function basefiles() {
  pacstrap /mnt base base-devel wpa_supplicant dialog  git python python-pip terminus-font
  genfstab -t PARTLABEL /mnt | grep -v 'swap' > /mnt/etc/fstab
  echo '/swapfile none swap defaults 0 0' >> /mnt/etc/fstab
}



#network
#filesystems
#mirrors
#basefiles
