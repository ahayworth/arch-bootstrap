#!/bin/bash

set -ex

PACKAGES="base base-devel linux linux-firmware terminus-font dhcpcd diffutils inetutils logrotate man-db man-pages vim texinfo usbutils which crda dnsutils dosfstools ethtool exfat-utils iwd mtools ntp openssh sudo usb_modeswitch curl wget wireless-regdb wireless_tools wpa_supplicant e2fsprogs device-mapper less git python-pip tmux lsb-release efibootmgr iputils iw dracut intel-ucode"
DISK='/dev/nvme0n1'

if [[ "$1" == "" ]]; then
  echo "Please specify --stage-{one,two,three}"
  exit 1
fi

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

check_network || setup_network

if [[ "$1" == "--stage-one" ]]; then
  pacman -Sy
  pacman -S --noconfirm reflector
  reflector --verbose --latest 5 --sort rate --protocol https --country 'United States' --save /etc/pacman.d/mirrorlist

  timedatectl set-ntp true

  parted -s $DISK \
    mklabel gpt \
    mkpart primary fat32 1MiB 551MiB name 1 efi set 1 esp on \
    mkpart primary linux-swap 551MiB 30518MiB name 2 swap \
    mkpart primary ext4 30518MiB 100% name 3 root

  mkfs.fat -F32 -n boot ${DISK}p1
  mkswap -L swap ${DISK}p2
  swapon ${DISK}p2
  mkfs.ext4 -L root ${DISK}p3

  mount ${DISK}p3 /mnt
  mkdir /mnt/boot
  mount ${DISK}p1 /mnt/boot

  pacstrap /mnt $PACKAGES
  genfstab -L /mnt >> /mnt/etc/fstab

  cp "$0" /mnt/
  arch-chroot /mnt /$(basename "$0") --stage-two
elif [[ "$1" == "--stage-two" ]]; then
  ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
  setfont ter-v22n
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
FONT=ter-v22n
EOF

  echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist-nouveau.conf
  dracut --hostonly --kver $(ls /lib/modules) --force /boot/initramfs-linux.img

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
