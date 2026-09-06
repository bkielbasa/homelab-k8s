# mini2 — the running NixOS k8s worker (since 2026-08-31).
#
# This node is LIVE and part of the cluster. Its full, working system
# config lives in /etc/nixos on the box. Until we have fully ported it
# into this repo, we import a snapshot of it so colmena NEVER strips the
# k8s services it runs today (kubelet + containerd + flannel).
#
# First-time port (run ONCE from the control machine):
#   scp root@mini2:/etc/nixos/configuration.nix nixos/machines/mini2/current.nix
#   scp root@mini2:/etc/nixos/hardware-configuration.nix nixos/machines/mini2/hardware-configuration.nix
#   colmena apply --on mini2
#
# Afterwards, retire the snapshot by merging its contents into this file
# (or keeping the import — both are fine; the snapshot is 100% declarative).
{ lib, pkgs, inputs, ... }:

{
  imports = [
    ./mini2/current.nix
    ./mini2/hardware-configuration.nix
  ];

  networking.hostName = "mini2";
  system.stateVersion = "26.05";
}