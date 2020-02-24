#!/bin/bash

set -eo pipefail

PACSTRAP_PACKAGES=(
  'base'
  'base-devel'
  'curl'
  'dhcpcd'
  'dosfstools'
  'e2fsprogs'
  'efibootmgr'
  'exfat-utils'
  'git'
  'intel-ucode'
  'iw'
  'iwd'
  'less'
  'linux'
  'linux-firmware'
  'man-db'
  'man-pages'
  'openssh'
  'sudo'
  'terminus-font'
  'texinfo'
  'vim'
  'wget'
  'wireless_tools'
)

function prompt_continue() {
  echo "$1" && read -p 'Press enter to continue...'
}

read -p 'Enter the desired hostname: ' system_hostname
read -p 'Enter the desired domain name: ' system_domain
read -p 'Enter your username: ' system_user
prompt_continue "Continuing with ${system_user}@${system_hostname}.${system_domain}"

ping -c 1 -w 1 8.8.8.8 2>&1 >/dev/null || \
  prompt_continue "Please configure the network in another tty."

prompt_continue "Please partition the disk in another tty."

pacman -Sy --noconfirm reflector
reflector --verbose --latest 5 --sort rate \
  --protocol https --country 'United States' \
  --save /etc/pacman.d/mirrorlist

timedatectl set-ntp true

pacstrap /mnt ${PACSTRAP_PACKAGES[@]}
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
arch-chroot /mnt hwclock --systohc

echo 'en_US.UTF-8 UTF-8' > /mnt/etc/locale.gen
echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

echo "${system_hostname}" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${system_hostname}.${system_domain} ${system_hostname}
EOF

cat > /mnt/etc/vconsole.conf <<EOF
KEYMAP=us
FONT=ter-v22n
EOF

arch-chroot /mnt bootctl --path=/boot install
cat > /mnt/boot/loader/loader.conf <<EOF
default arch
timeout 4
console-mode max
editor no
EOF

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
options root=LABEL=root
initrd /intel-ucode.img
initrd /initramfs-linux.img
EOF

arch-chroot /mnt useradd -m -u 1000 ${system_user}
arch-chroot /mnt usermod -G wheel -a ${system_user}
echo "Set the password for user ${system_user}..."
arch-chroot /mnt passwd ${system_user}
echo '%wheel ALL=(ALL) ALL' >> /mnt/etc/sudoers

echo "Set the root password..."
arch-chroot /mnt passwd

echo "All done. Reboot and continue with aconfmgr."

#arch-chroot /mnt ln -sf /usr/bin/vim /usr/bin/vi
