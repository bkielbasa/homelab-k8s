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

  # Dev/workstation-ish box: ethernet via NetworkManager. Wi-Fi (Intel
  # iwlwifi) is intentionally disabled — it had to be blacklisted on the
  # previous Ubuntu install, keep it that way here.
  networking.networkmanager.enable = true;
  boot.blacklistedKernelModules = [ "iwlwifi" "iwlmvm" "cfg80211" ];

  # nixos-anywhere builds nixosConfigurations.laptop, which does not import
  # modules/common.nix (colmena does). Without this, the installed system has
  # no sshd and the default firewall drops port 22. openFirewall defaults on.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # This box is a headless worker. Closing the lid must not suspend it,
  # on battery, on AC, or in a dock.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # ------------------------------------------------------------------
  # Users
  # ------------------------------------------------------------------
  users.users.bklimczak = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme"; # change after first login
    openssh.authorizedKeys.keys = [
      # Control machine (mini-pc) key used by colmena
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAJaCuS/oQqN+AmmwAPwYNOwdKtl3ZhsfFEYfxR95CwT bklimczak@mini-pc"
      # Jumphost (mini2). ssh-copy-id cannot install this: password auth is
      # off and these keys are owned by the NixOS config.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGhNeI6xFkYmYvyYNZh/Ih3ZT7DkHgXJyRylE6ttKy6j bklimczak@mini2"
      # Personal key
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzdCbnPkhIvwE4lVVKVF9bcAyz4gNeurZ//B6y3Ed5e bartlomiej.klimczak@bayer.com"
    ];
  };

  # Root key for bootstrapping / colmena logins (root@).
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAJaCuS/oQqN+AmmwAPwYNOwdKtl3ZhsfFEYfxR95CwT bklimczak@mini-pc"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGhNeI6xFkYmYvyYNZh/Ih3ZT7DkHgXJyRylE6ttKy6j bklimczak@mini2"
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