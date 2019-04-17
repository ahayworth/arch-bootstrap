#!/bin/bash -x

function dotfiles() {
  cd $HOME
  git clone git@github.com:ahayworth/dotfiles
  dotfiles/dotdrop.sh install || /bin/true
  pip install -r dotfiles/dotdrop/requirements.txt --user
  dotfiles/dotdrop.sh install
}

function aur() {
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si
  cd $HOME
  rm -rf /tmp/yay
}

function termfont() {
  sudo bash -c "echo 'FONT=ter-124n' > /etc/vconsole.conf"
  setfont ter-124n
}

function mkinitcpio() {
  grep -q 'i915' /etc/mkinitcpio.conf || echo 'Add i915 to MODULES in /etc/mkinitcpio.conf'
  grep -q 'sd-vconsole' /etc/mkinitcpio.conf || echo 'Add sd-vconsole to HOOKS in /etc/mkinitcpio.conf'
  grep -q 'systemd' /etc/mkinitcpio.conf || echo 'Add systemd to HOOKS in /etc/mkinitcpio.conf'
  sudo mkinitcpio -p linux
}

function graphics() {
  sudo bash -c "echo 'options i915 enable_guc=3 fastboot=1' > /etc/modprobe.d/i915.conf"
  sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter accountsservice light-locker
  sudo systemctl enable lightdm.service
  xfconf-query -c xfce4-session -p /general/LockCommand -s "light-locker-command --lock" --create -t string
}

function desetup() {
  sudo pacman -S udisks2 networkmanager
  sudo systemctl enable NetworkManager.service
}

#dotfiles
#aur
#termfont
#mkinitcpio
#graphics
#desetup
