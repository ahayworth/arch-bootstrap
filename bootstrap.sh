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

  sfdisk --part-type ${DISK} 3 4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709

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
HOOKS=(systemd sd-plymouth autodetect block filesystems modconf sd-vconsole keyboard fsck)
COMPRESSION="cat"
EOF

  efibootmgr --disk ${DISK} --part 1 --create --label 'Arch Linux' --loader /vmlinuz-linux --verbose \
    --unicode "root=/dev/${DISK}p3 rw quiet loglevel=0 rd.systemd.show_status=auto rd.udev.log_priority=3 i915.fastboot=1 vga=current initrd=\intel-ucode.img initrd=\initramfs-linux.img"

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
  pacman -S --noconfirm --asdeps bash-completion reflector
  systemctl enable gdm
  pacman -S --noconfirm s-tui htop cpupower
  sed -i'' -e "s/#governor='ondemand'/governor='performance'/" /etc/default/cpupower
  systemctl enable cpupower

  systemctl enable bluetooth
  systemctl enable NetworkManager

  pacman -S --noconfirm vulkan-intel vulkan-icd-loader intel-media-driver libva-utils vulkan-tools
  echo 'options i915 enable_guc=3 enable_fbc=1' > /etc/modprobe.d/i915.conf
  mkinitcpio -p linux

  echo 'options snd_hda_intel power_save=1' > /etc/modprobe.d/audio_powersave.conf

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
  pacman -S steam lib32-primus_vk
  yay -S slack-desktop

  mkdir -p /etc/dconf/profile
  cat >> /etc/dconf/profile/gdm <<EOF
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

  mkdir -p /etc/dconf/db/gdm.d
  cat >> /etc/dconf/db/gdm.d/02-clock <<EOF
[org/gnome/desktop/interface]
clock-format='12h'
EOF
  dconf update
  pacman -S adapta-gtk-theme arc-gtk-theme arc-icon-theme gtk-engine-murrine noto-fonts ttf-roboto

  pacman -S powertop gnome-software-packagekit-plugin gnome-power-manager

  cat >> /etc/systemd/system/powertop.service <<EOF
[Unit]
Description=Powertop tunings

[Service]
Type=exec
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable powertop

  pacman -S lib32-libpulse lib32-alsa-plugins pulseeffects
  curl -L -o '/home/andrew/.config/PulseEffects/irs/Dolby ATMOS ((128K MP3)) 1.Default.irs' 'https://github.com/JackHack96/PulseEffects-Presets/raw/master/irs/Dolby%20ATMOS%20((128K%20MP3))%201.Default.irs'
  yay -S thermald dptfxtract-bin
  dptfxtract -o /etc/thermald
  mv thermal-conf* /etc/thermald/
  systemctl enable --now thermald

  yay -S intel-undervolt
  sed -i'' -e "s/undervolt 0 'CPU' 0/undervolt 0 'CPU' -100" /etc/intel-undervolt.conf
  sed -i'' -e "s/undervolt 0 'CPU Cache' 0/undervolt 0 'CPU Cache' -100" /etc/intel-undervolt.conf
  systemctl enable --now intel-undervolt

  pacman -S cups hplip python-pyqt5
  yay -S hplip-plugin
  systemctl enable --now org.cups.cupsd.socket
  systemctl enable --now org.cups.cupsd.service

  systemctl enable fstrim.timer

  #pacman -S alacritty alacritty-terminfo
  yay -S nerd-fonts-hack alacritty-git alacritty-terminfo-git

  pacman -S zsh
  chsh -s /usr/bin/zsh andrew

  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    area-screenshot \
    "['<Shift><Alt>4']"
  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    area-screenshot-clip \
    "['<Ctrl><Shift><Alt>4']"

  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    screenshot \
    "['<Shift><Alt>5']"
  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    screenshot-clip \
    "['<Ctrl><Shift><Alt>5']"

  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    window-screenshot \
    "['<Shift><Alt>6']"
  gsettings set org.gnome.settings-daemon.plugins.media-keys \
    window-screenshot-clip \
    "['<Ctrl><Shift><Alt>6']"

  gsettings set org.gnome.desktop.input-sources \
    xkb-options \
    "['compose:prsc','caps:escape']"

  gsettings set org.gnome.desktop.interface \
    show-battery-percentage \
    "true"

  yay -S firefox-nightly
  yay -S chromium-vaapi-bin
  yay -S chromium-widevine
  cat > ~/.config/chromium-flags.conf << EOF
--ignore-gpu-blacklist
--enable-gpu-rasterization
--enable-oop-rasterization
--enable-native-gpu-memory-buffers
--enable-zero-copy
--use-gl=egl
--enable-features=UseSkiaRenderer,VizHitTestSurfaceLayer
EOF

  pacman -S nvme-cli intel-gpu-tools bluez-utils
  usermod -G lp -a andrew
  mkdir -p /var/lib/gdm/.config/pulse
  cat > /var/lib/gdm/.config/pulse/client.conf <<EOF
autospawn = no
daemon-binary = /bin/true
EOF
  chown gdm:gdm /var/lib/gdm/.config/pulse/client.conf

  yay -S nordic-theme-git

  echo 'vm.dirty_writeback_centisecs = 3000' > /etc/sysctl.d/writeback.conf
  echo 'options iwlwifi power_save=1 uapsd_disable=0' > /etc/modprobe.d/iwlwifi.conf

  pacman -S linux-zen
  pacman -Rnu bbswitch
  pacman -S linux-zen-headers
  yay -S bbswitch-dkms
  num=`efibootmgr | grep Arch | awk '{print $1}' | sed -E -e 's/(Boot|\*)//g'`
  efibootmgr -b $num -B
  efibootmgr --disk ${DISK} --part 1 --create --label 'Arch Linux' --loader /vmlinuz-linux-zen --verbose \
    --unicode "root=/dev/${DISK}p3 rw quiet splash i915.fastboot=1 loglevel=3 rd.udev.log_priority=3 rd.systemd.show_status=auto vga=current initrd=\intel-ucode.img initrd=\initramfs-linux-zen.img"


  yay -S plymouth-git gdm-plymouth ttf-dejavu
  systemctl disable gdm
  systemctl enable gdm-plymouth

  curl -L -o /tmp/uefi-shell.zip 'https://github.com/tianocore/edk2/releases/download/edk2-stable201908/ShellBinPkg.zip'
  unzip /tmp/uefi-shell.zip -d /tmp/uefi-shell
  cp /tmp/uefi-shell/ShellBinPkg/UefiShell/X64/Shell.efi /boot/
  rm -rf /tmp/uefi-shell
  efibootmgr --disk ${DISK} --part 1 --create --label 'UEFI Shell' --loader /Shell.efi --verbose
  efibootmgr -o 0001,0000

  yay -S ttf-symbola p7zip
  unzip windows.zip -d /usr/share/fonts
  rm -rf /usr/share/fonts/windows/.NET*
  fc-cache -f

  yay -S visual-studio-code-bin

  yay -S pam-python python-face_recognition python-face_recognition_models
  (cd howdy && makepkg -si)

  yay -S chrome-gnome-shell

  pacman -S docker docker-compose
  usermod -G docker -a andrew

  pacman -S lm_sensors
  pacman -S libgtop lm_sensors gnome-icon-theme-symbolic

  gpg --recv-key 06CA9F5D1DCF2659
  yay -S ofono phonesim
  systemctl enable --now ofono

  pacman -Ss ansible python-passlib sshpass
  cat >> /etc/NetworkManager/conf.d/wifi_backend.conf <<EOF
[device]
wifi.backend=iwd
EOF
  systemctl enable --now iwd
  systemctl restart NetworkManager

  pacman -S dbus-broker
  systemctl enable --now dbus-broker
  systemctl enable --global dbus-broker

  pacman -S systemd-resolvconf
  systemctl enable --now systemd-resolved
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  cat >> /etc/NetworkManager/conf.d/mdns.conf <<EOF
[connection]
connection.mdns=2
connection.llmnr=2
EOF


  # TODO: gst plugins, power and thermal management
  # TODO: go through power management page again, look into usb autosuspend, sata autosuspend, pcie autosuspend
  # TODO: zswap?
  # gnome boxes (qemu, look at libvit dependencies)
  # wiki page for x1 extreme
  # configure gdm
  # export pulseeffects profiles?
  # export favorites for gnome shell?
  # fonts
  # rebuild packages for -march=<foo>
  # themes
  # figure out PCIE ASPM
  # figure out if we want to early-adopt iwd for networkmanager backend

  # FAR-off TODO:
  # caps -> esc in console
  # configure tmux/nord: https://github.com/arcticicestudio/nord-tmux/tree/v0.3.0/src
  # configure vim/nord: https://github.com/arcticicestudio/nord-vim
  # thinkpad things:
  # thinkpad-wmi
  # tp_smapi
  # tpacpi-bat
  # threshy
  # tp-battery-mode
  # thinkalert
  # thinkfan
  # thinkgui
fi
