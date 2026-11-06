# laptop — NixOS k8s worker.
#
# Disk layout is in ../disko/laptop.nix (destructive; used by nixos-anywhere).
# Kubernetes binaries are pinned to NixOS 26.05 (1.36.3). The flake nixpkgs
# default is 1.37, which the 1.36 API server rejects. Joining is still
# `kubeadm join` against raspberrypi (192.168.1.29), same as mini2.
{ lib, pkgs, inputs, ... }:
let
  pkgsK8s = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/5880666fd9eb563038431edb35c2d0aa595884e6.tar.gz";
    sha256 = "sha256-OURZPknrTjQrlNyxPdqzyqmU/81Wes1CUP/Ft1Rv/YI=";
  }) { system = "x86_64-linux"; };
in
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
  # mini2 runs with the firewall off. Flannel (UDP 8472) and kubelet
  # need that; the NixOS firewall would drop forwarded pod traffic.
  networking.firewall.enable = false;
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
  # k8s worker. Same shape as mini2: containerd + CNI plugins in
  # /opt/cni/bin (where the flannel DaemonSet installs its plugin) and a
  # kubelet unit. `kubeadm join` fills in /etc/kubernetes and
  # /var/lib/kubelet/config.yaml; until then kubelet restarts.
  # ------------------------------------------------------------------
  swapDevices = [ ];

  environment.systemPackages = [
    pkgsK8s.kubernetes
    pkgs.cni-plugins
    pkgs.conntrack-tools
    pkgs.ethtool
    pkgs.socat
    pkgs.iptables
    pkgs.nfs-utils
  ];

  virtualisation.containerd.enable = true;
  virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri" = {
    cni.bin_dir = "/opt/cni/bin";
    cni.conf_dir = "/etc/cni/net.d";
    containerd.runtimes.runc.options.SystemdCgroup = true;
  };

  system.activationScripts.cniPlugins.text = ''
    mkdir -p /opt/cni/bin /etc/cni/net.d
    ln -sfn ${pkgs.cni-plugins}/bin/* /opt/cni/bin
  '';

  boot.kernelModules = [ "br_netfilter" "overlay" "nf_conntrack" "nf_nat" "xt_conntrack" "nf_tables" ];
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.ipv4.ip_forward" = 1;
  };

  systemd.services.kubelet = {
    description = "Kubernetes kubelet";
    wantedBy = [ "multi-user.target" ];
    after = [ "containerd.service" ];
    serviceConfig = {
      Environment = "PATH=/run/current-system/sw/bin:/usr/bin:/bin";
      ExecStart = ''
        ${pkgsK8s.kubernetes}/bin/kubelet \
          --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
          --kubeconfig=/etc/kubernetes/kubelet.conf \
          --config=/var/lib/kubelet/config.yaml \
          --container-runtime-endpoint=unix:///run/containerd/containerd.sock
      '';
      Restart = "always";
      RestartSec = "10";
    };
  };

  # ------------------------------------------------------------------
  # GUI / general purpose (uncomment what you want)
  # ------------------------------------------------------------------
  # services.displayManager.sddm.enable = true;
  # services.desktopManager.plasma6.enable = true;
  # programs.river.enable = true;
}