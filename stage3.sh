#!/bin/bash -x


function aur() {
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si
  cd $HOME
  rm -rf /tmp/yay
}

function graphics() {
  sudo bash -c "echo 'options i915 enable_guc=3 fastboot=1' > /etc/modprobe.d/i915.conf"
  sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter accountsservice xorg-server xscreensaver lightdm-gtk-greeter-settings
  yay -S xfce4-screensaver xscreensaver-aerial-videos-1080
  sudo systemctl enable lightdm.service
  xfconf-query -c xfce4-session -p /general/LockCommand -s "xfce4-screensaver-command -l" --create -t string
}

function desetup() {
  sudo pacman -S --noconfirm udisks2 networkmanager network-manager-applet xdg-user-dirs pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-equalizer pamixer bluez bluez-utils blueman pavucontrol gvfs xorg-xprop arc-gtk-theme arc-icon-theme gtk-engine-murrine
  sudo systemctl enable NetworkManager.service
  modprobe btusb || /bin/true
  sudo systemctl enable bluetooth.service
  sudo systemctl enable fstrim.timer
}

function appsetup() {
  pacman -S --noconfirm tlp tlp-rdw python-gobject smartmontools redshift python-xdg mlocate
  yay -S tlpui-git google-chrome
  sudo systemctl enable tlp.service
  sudo systemctl enable tlp-sleep.service
  sudo updatedb
}

function fonts() {
  sudo pacman -S ttf-bitstream-vera ttf-croscore ttf-roboto noto-fonts ttf-liberation ttf-ubuntu-font-family ttf-anonymous-pro ttf-freefont ttf-fira-mono ttf-inconsolata ttf-hack adobe-source-code-pro-fonts ttf-linux-libertine noto-fonts-emoji
  yay -S ttf-meslo ttf-monaco otf-eb-garamond ttf-twemoji-color ttf-emojione otf-san-francisco ttf-mac-fonts
}
