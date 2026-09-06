# laptop — the future NixOS reinstall target.
#
# The machine currently runs Ubuntu and is a k8s worker. Plan:
#   1. run nixos-anywhere with this config to wipe + install NixOS
#   2. rejoin it to the cluster as a worker (see "k8s worker" note below)
# This file is intentionally minimal — the disk layout in ./disko
# is destructive, so nothing here runs until *you* run nixos-anywhere.
{ lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko
    ../disko/laptop.nix
  ];

  networking.hostName = "laptop";

  # UEFI boot for the disko layout in ../disko/laptop.nix.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep this equal to the NixOS version you install (26.05).
  system.stateVersion = "26.05";

  # Dev/workstation-ish box: wifi + ethernet via NetworkManager.
  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------
  # Users
  # ------------------------------------------------------------------
  users.users.bklimczak = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      # TODO(you): paste your real SSH pubkey.
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
    ];
  };

  # Root key for bootstrapping / colmena logins (root@). Replace with
  # your real key. Until then sshd will ignore this bogus entry.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAEXAMPLE_REPLACE_ME"
  ];

  users.mutableUsers = false;

  # ------------------------------------------------------------------
  # k8s worker — TODO: rejoin the cluster after the reinstall.
  #
  # Mirror the kubelet + containerd + flannel setup the node runs today
  # (docker-style containerd 2.x + kubelet, joined via the bootstrap used
  # for the rest of the lab). Until this block is filled in, the freshly
  # installed laptop is NOT part of the cluster.
  # ------------------------------------------------------------------

  # ------------------------------------------------------------------
  # GUI / general purpose (uncomment what you want)
  # ------------------------------------------------------------------
  # services.displayManager.sddm.enable = true;
  # services.desktopManager.plasma6.enable = true;
  # programs.river.enable = true;
}