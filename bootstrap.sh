#!/bin/bash

set -ex

PACKAGES="base base-devel linux linux-firmware terminus-font dhcpcd diffutils inetutils logrotate man-db man-pages vim texinfo usbutils which crda dnsutils dosfstools ethtool exfat-utils iwd mtools ntp openssh sudo usb_modeswitch curl wget wireless-regdb wireless_tools wpa_supplicant e2fsprogs device-mapper less git python-pip tmux lsb-release efibootmgr iputils iw intel-ucode"
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

[Settings]
Autoconnect=True
EOF

  sed -i'' -e 's/# enable_network_config=False/enable_network_config=True/' /etc/iwd/main.conf
  sed -i'' -e 's/# dns_resolve_method=systemd/dns_resolve_method=resolvconf/' /etc/iwd/main.conf

  systemctl start iwd
  iwctl station wlan0 connect "$ssid"
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
  arch-chroot /mnt /mnt/$(basename "$0") --stage-two
elif [[ "$1" == "--stage-two" ]]; then
  ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
  setfont ter-v22n
  hwclock --systohc
  echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  locale-gen
  echo 'janeway' > /etc/hostname

  cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 janeway.boyfriend.network janeway
EOF

  cat > /etc/vconsole.conf <<EOF
KEYMAP=us
FONT=ter-v22n
EOF

  echo 'blacklist nouveau' >> /etc/modprobe.d/blacklist-nouveau.conf
  cat > /etc/mkinitcpio.conf <<EOF
MODULES=(i915 battery)
BINARIES=()
FILES=()
HOOKS=(systemd autodetect block filesystems modconf sd-vconsole keyboard)
COMPRESSION="cat"
EOF

  efibootmgr --disk ${DISK} --part 1 --create --label 'Arch Linux' --loader /vmlinuz-linux --verbose \
    --unicode 'root=/dev/${DISK}p3 rw quiet loglevel=3 rd.systemd.show_status=auto rd.udev.log_priority=3 i915.fastboot=1 vga=current initrd=\intel-ucode.img initrd=\initramfs-linux.img'
    #--unicode "root=${DISK}p3 rw initrd=\intel-ucode.img initrd=\initramfs-linux.img rd.driver.blacklist=nouveau rd.luks=0 rd.lvm=0 rd.md=0 rd.dm=0"

  ln -sf /usr/bin/vim /usr/bin/vi
  useradd -m -u 1000 andrew
  usermod -G wheel -a andrew
  echo "set password for andrew"
  passwd andrew

  echo "set password for root"
  passwd

  echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
elif [[ "$1" == "--stage-three" ]]; then
  pacman -S --noconfirm gnome gnome-extra
  # TODO: pacdep from aur
  pacman -S --noconfirm --asdeps bash-completion reflector
  # TODO: consider fwupd, gst plugins, graphics and acceleration, power and thermal management
  # do i need samba client support any more?
  # gnome boxes (qemu, look at libvit dependencies)
  #  also: battery module
  #  also: pacman hook for update
  # wiki page for x1 extreme
  systemctl enable gdm
  # configure gdm
  pacman -S --noconfirm s-tui throttled htop cpupower
  systemctl enable lenovo_fix
  sed -i'' -e "s/#governor='ondemand'/governor='performance'/" /etc/default/cpupower
  systemctl enable cpupower

  echo 'options psmouse synaptics_intertouch=1' > /etc/modprobe.d/psmouse.conf
  systemctl enable bluetooth
  systemctl enable NetworkManager

  pacman -S --noconfirm vulkan-intel vulkan-icd-loader intel-media-driver libva-utils vulkan-tools
  echo 'options i915 enable_guc=3 enable_fbc=1' > /etc/modprobe.d/i915.conf
  mkinitcpio -p linux

  mkdir -p ~andrew/.config/environment.d
  echo 'LIBVA_DRIVER_NAME=iHD' >> ~andrew/.config/environment.d/envvars.conf
  chown -R andrew: ~andrew/.config/environment.d

  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  chown -R andrew: yay
  cd yay
  sudo -u andrew makepkg -si
  yay -S nvidia-beta
  pacman -S primus_vk bbswitch
  systemctl enable --now bumblebeed
  usermod -G bumblebee -a andrew

  cat >> /etc/pacman.conf <<EOF
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

  pacman -Sy
  pacman -S steam
  yay -S slack-desktop
fi
