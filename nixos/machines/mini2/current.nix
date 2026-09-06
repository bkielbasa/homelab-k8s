# Snapshot of mini2's running config — see ../mini2.nix.
#
# Copy the live config here (from the control machine):
#   scp root@mini2:/etc/nixos/configuration.nix nixos/machines/mini2/current.nix
#   scp root@mini2:/etc/nixos/hardware-configuration.nix nixos/machines/mini2/hardware-configuration.nix
{ lib, ... }:
let
  canary = builtins.readFile ./hardware-configuration.nix;
in
if lib.hasInfix "PLACEHOLDER_REPLACE_ME" canary
then abort ''
  machines/mini2: the ported /etc/nixos snapshot is still a placeholder,
  so this host refuses to build. Copy the real config from the box first
  (see nixos/README.md) — otherwise colmena would strip mini2's k8s
  services on the next apply.
''
else { }