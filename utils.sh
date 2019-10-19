#!/bin/bash

function check_network() {
  ping -c 1 -w 1 8.8.8.8 2>&1 >/dev/null
}

function setup_network() {
  read -p 'Enter wifi ssid: ' ssid
  read -p 'Enter wifi password: ' ssid_psk
  cat > /var/lib/iwd/$ssid.psk <<EOF
[Security]
PreSharedKey=$(wpa_passphrase "$ssid" $ssid_psk | grep -v '#' | grep psk | cut -d '=' -f2)
EOF

  systemctl start iwd
  iwctl station wlan0 connect "$ssid"
  dhcpcd
}

function partition() {
  parted -s $DISK mklabel gpt
  parted -s $DISK mkpart primary fat32 1MiB 551MiB name 1 efi set 1 esp on
  parted -s $DISK mkpart primary swap 551MiB 30518MiB name 2 swap set 2 swap on
  parted -s $DISK mkpart primary ext4 30518MiB 100% name 3 root set 3 root on

  mkfs.fat -F32 -n boot ${DISK}p1
  mkswap -L swap ${DISK}p2
  swapon ${DISK}p2
  mkfs.ext4 -L root ${DISK}p3
}

function mount_fs() {
  mount ${DISK}p3 /mnt
  mkdir /mnt/boot
  mount ${DISK}p1 /mnt/boot
}

function installpkg() {
  pacman -Sy
  pacman -S --noconfirm "$@"
}

function installbase() {
  pacstrap /mnt $PACKAGES
}
