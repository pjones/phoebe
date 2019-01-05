#!/bin/sh

################################################################################
#
# Bootstrap NixOS on Linode.
#
# Based on (read this so you know what's going on):
#
#   https://gist.github.com/nocoolnametom/a359624afce4278f16e2760fe65468ccd
#
# Prerequisites:
#
#   1. Create three (3) disk images:
#
#      - Installer: 650MB (or big enough for the NixOS ISO)
#      - Swap: 256MB (Linode recommendation)
#      - NixOS: >= 4GB
#
#   2. Boot from the Rescue page with disks set up like:
#
#      - /dev/sda -> Installer Disk
#      - /dev/sdb -> Swap Disk
#      - /dev/sdc -> NixOS Disk
#
#      NOTE: This is the default setting but it's different than the
#      instructions from nocoolnametom.
#
#   3. When you are booted into Finnix (step 2) pipe this script to sh:
#
#          curl -k <url> | sh
#
#      The machine will stop running after NixOS was written to the
#      installer disk.
#
#   4. Create a new configuration profile for installing NixOS:
#
#        - Kernel: Direct
#        - /dev/sda -> Installer Disk
#        - /dev/sdb -> Swap
#        - /dev/sdc -> NixOS
#        - Filesystem/Boot Helpers: All off
#
#      NOTE: Disk order is unimportant here, except that the installer
#      disk should be on /dev/sda.
#
#   5. Reboot into the installer profile.
#
#      NOTE: You'll need to quickly press TAB when the Grub menu
#      appears and enter the following before pressing ENTER:
#
#          console=ttyS0
#
#   6. Run this script again, just like in step 3.
#
#   7. Create the final configuration for your new server and boot
#      into NixOS (more details can be found in the guide referenced
#      above).

################################################################################
set -e
set -u
set -x

################################################################################
# FIXME: Calculate this URL at run time:
NIXOS_URL="https://d3g5gsiof5omrk.cloudfront.net/nixos/18.09/nixos-18.09.1834.9d608a6f592/nixos-minimal-18.09.1834.9d608a6f592-x86_64-linux.iso"

################################################################################
# Label the disks so the rest of the script only uses labels.
label_disks() {
  e2label /dev/sda installer
  e2label /dev/sdc nixos
  swaplabel -L swap /dev/sdb
}

################################################################################
# Download the NixOS ISO and write it to the installer disk.
write_installer_to_disk() {
  curl -k "$NIXOS_URL" \
    | dd bs=1M of=/dev/disk/by-label/installer

  sync
}

################################################################################
# Prepare NixOS disk and swap disk:
prep_nixos_disks() {
  mount /dev/disk/by-label/nixos /mnt
  swapon /dev/disk/by-label/swap
}

################################################################################
# Given a disk label, update the hardware configuration so the UUID is
# replaced with a disk lable.
hardware_uuid_to_label() {
  label=$1
  uuid=$(blkid --match-tag UUID --output value /dev/disk/by-label/"$label")

  sed -i \
      -e "s|/dev/disk/by-uuid/$uuid|/dev/disk/by-label/$label|" \
      /mnt/etc/nixos/hardware-configuration.nix
}

################################################################################
# Update configuration.nix with recommended Grub settings:
update_grub_settings() {
  # Remove all current grub lines:
  sed -i \
      -e '/boot\.loader\.grub/d' \
      -e '/boot\.kernelParams/d' \
      -e '/^}$/d' \
      /mnt/etc/nixos/configuration.nix

  cat >> /mnt/etc/nixos/configuration.nix <<EOF
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.copyKernels = true;
  boot.loader.grub.fsIdentifier = "label";
  boot.loader.grub.extraConfig = "serial; terminal_input serial; terminal_output serial";
  boot.kernelParams = [ "console=ttyS0" ];
}
EOF
}

################################################################################
# Enable SSH and allow root to login (So you can use NixOps later).
enable_ssh() {
  # Remove the closing curly:
  sed -i -e '/^}$/d' /mnt/etc/nixos/configuration.nix

  cat >> /mnt/etc/nixos/configuration.nix <<EOF
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  services.openssh.openFirewall = true;
}
EOF
}

################################################################################
if [ "$(hostname)" = "finnix" ]; then
  label_disks
  write_installer_to_disk
  halt
else
  prep_nixos_disks
  nixos-generate-config --root /mnt
  hardware_uuid_to_label nixos
  hardware_uuid_to_label swap
  update_grub_settings
  enable_ssh
  nixos-install
  shutdown now
fi
