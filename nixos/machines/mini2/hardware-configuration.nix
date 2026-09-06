# PLACEHOLDER_REPLACE_ME — Warns loudly if someone applies colmena to mini2
# without the ported snapshot: the /etc/nixos copy must exist for the node
# to keep its k8s services.
{ lib, ... }:

{
  # Generated on mini2 by `nixos-generate-config` during the install.
  # Replace with the real file copied from the box.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme" "sd_mod" "usb_storage" "ahci"
  ];
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };
}