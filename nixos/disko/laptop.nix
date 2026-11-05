# Disk layout for the laptop — used by nixos-anywhere during the
# bootstrapping of a fresh machine.
#
# WARNING: applying this WIPES the target disk. Verify /dev/nvme0n1
# (or change `device`) before use.
{ lib, ... }:

{
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/sda"; # SATA SSD (WDC WDS240G2G0B, 223.6G) - verified via lsblk
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00"; # EFI system partition
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            mountpoint = "/";
          };
        };
      };
    };
  };

  # Also convert this machine to be used for disko interactively:
  #   disko --mode disko ./nixos/disko/laptop.nix  (after `nix develop`)
}