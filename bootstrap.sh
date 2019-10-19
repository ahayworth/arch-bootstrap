#!/bin/bash

set -ex

PACKAGES="base base-devel linux linux-firmware terminus-font dhcpcd diffutils inetutils logrotate man-db man-pages vim texinfo usbutils which crda dnsutils dosfstools ethtool exfat-utils iwd mtools ntp openssh sudo usb_modeswitch curl wget wireless-regdb wireless-tools wpa_supplicant e2fsprogs device-mapper less git python-pip tmux lsb-release efibootmgr iputils iw dracut intel-ucode"
DISK='/dev/nvme0n1'

if [[ "$1" == "" ]]; then
  echo "Please specify --stage-{one,two,three}"
  exit 1
fi

. ./utils.sh

check_network || setup_network

if [[ "$1" == "--stage-one" ]]; then
  installpkg "reflector"
  reflector --verbose --latest 5 --sort rate --protocol https --country 'United States' --save /etc/pacman.d/mirrorlist

  timedatectl set-ntp true

  partition
  mount_fs

  installbase
  genfstab -L /mnt >> /mnt/etc/fstab

  cp "$0" /mnt/
  arch-chroot /mnt /mnt/$(basename "$0") --stage-two
elif [[ "$1" == "--stage-two" ]]; then
  ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
  setfont ter-v132n
  hwclock --systohc
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  locale-gen
  echo 'janeway' > /etc/hostname

  echo > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 janeway.boyfriend.network janeway
EOF

  echo > /etc/vconsole.conf <<EOF
KEYMAP=us
FONT=ter-v132n
EOF

  echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist-nouveau.conf
  dracut --hostonly --force /boot/initramfs-linux.img

  pacman -Rnu --noconfirm vi
  ln -sf /usr/bin/vim /usr/bin/vi
  efibootmgr --disk ${DISK} --part 1 --create --label 'Arch Linux' --loader /vmlinuz-linux --verbose \
    --unicode "root=${DISK}p3 rw initrd=\intel-ucode.img initrd=\initramfs-linux.img rd.driver.blacklist=nouveau rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0"
    #--unicode 'root=/dev/${DISK}p3 rw quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 i915.fastboot=1 vga=current initrd=\initramfs-linux.img'

  useradd -m -u 1000 andrew
  usermod -G wheel -a andrew
  echo "set password for andrew"
  passwd andrew

  echo "set password for root"
  passwd

  echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
elif [[ "$1" == "--stage-three" ]]; then
  echo "stage 3"
fi
