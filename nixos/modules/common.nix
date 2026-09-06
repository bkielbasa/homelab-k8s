# Shared configuration for every NixOS host in this homelab.
{ pkgs, lib, ... }:

{
  # ----------------------------------------------------------------------
  # Time / locale
  # ----------------------------------------------------------------------
  time.timeZone = "Europe/Warsaw";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "pl";

  # ----------------------------------------------------------------------
  # Nix
  # ----------------------------------------------------------------------
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Allow members of the wheel group to run nix commands un-authenticated.
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = true;
    };
    # Garbage collection: weekly, keep last 5 generations.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ----------------------------------------------------------------------
  # SSH: key-only auth. colmena deploys as root over SSH.
  # Replace the key with your actual pubkey (ssh-ed25519 ...).
  # ----------------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes"; # required for colmena/deploying as root
    };
  };

  # ----------------------------------------------------------------------
  # Network / firewall
  # ----------------------------------------------------------------------
  networking.firewall.enable = true;

  # ----------------------------------------------------------------------
  # NFS client support. The in-tree kubernetes.io/nfs volumes (e.g. the
  # jellyfin-media PV) need /sbin/mount.nfs from nfs-utils on the HOST,
  # otherwise kubelet fails with "mount program didn't pass remote address".
  # ----------------------------------------------------------------------
  boot.kernelModules = [ "nfs" "nfsv4" ];
  environment.systemPackages = with pkgs; [
    nfs-utils
    git
    vim
    htop
    tmux
    curl
    jq
    fzf
  ];

  # ----------------------------------------------------------------------
  # Limit the journal and syslog to something sane for embedded nodes.
  # ----------------------------------------------------------------------
  services.journald.extraConfig = ''
    SystemMaxUse=256M
    MaxRetentionSec=14d
  '';
}