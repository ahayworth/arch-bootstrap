#!/bin/bash -x

function moresetup() {
  ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
  hwclock --systohc
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  locale-gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  echo 'alpha5' > /etc/hostname

  cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 alpha5.localdomain alpha5
EOF

  pacman -Sy
  pacman -S --noconfirm intel-ucode
  bootctl --path=/boot install
  mkdir /etc/pacman.d/hooks

  cat > /etc/pacman.d/hooks/100-systemd-boot.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF

  cat > /boot/loader/loader.conf <<EOF
default arch
timeout 2
console-mode max
editor no
EOF

  cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTLABEL=root rw
EOF

  passwd
}

function usersetup() {
  pacman -S --noconfirm sudo 
  useradd -m -G wheel -s /bin/bash andrew
  passwd andrew
  cat > /etc/sudoers.d/wheel <<EOF
%wheel ALL=(ALL) ALL
EOF
}

function packagesetup() {
  pacman -S --noconfirm vim tmux openssh
  pacman -R --noconfirm vi
  ln -sf /usr/bin/vim /usr/bin/vi
}

#moresetup
#usersetup
#packagesetup
