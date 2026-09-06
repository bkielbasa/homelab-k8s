# NixOS for the homelab (colmena)

All NixOS machines in the homelab are defined here in git. You deploy
them from any control machine with Nix installed — you never ssh into a
node to change its config again.

## Layout

```
flake.nix                      colmena inventory + tooling
machines/laptop.nix            laptop: future NixOS reinstall target
machines/mini2.nix             mini2: live NixOS k8s worker
machines/mini2/                snapshot of mini2's current /etc/nixos
modules/common.nix             shared base (ssh, nfs-utils, firewall, ...)
disko/laptop.nix               disk layout for fresh installs
```

## Prereqs

- Control machine: any box with Nix (e.g. the laptop after it becomes
  NixOS). Mini-pc works too if you install nix there.
- SSH key that can log into each node **as root** (`deployment.targetUser`).
  Drop the key into `modules/common.nix` / the machine files.
- The nodes reachable on the LAN (mini2: 192.168.1.226, laptop: 192.168.1.160).

## Day-to-day

```sh
cd nixos
nix develop                 # drop into a shell with colmena, nixos-anywhere, disko

# edit a machine file, then:
colmena apply --on mini2     # single host
colmena apply                # everything
```

Colmena builds the new system on the control machine and pushes the
closure to the node over SSH; `nix` is not required on the nodes.

## Port mini2's live config into this repo (first time)

mini2 is a running k8s worker; its full working config lives in
`/etc/nixos` on the box. Import a snapshot so colmena doesn't strip its
kubelet/containerd services:

```sh
scp root@mini2:/etc/nixos/configuration.nix        nixos/machines/mini2/current.nix
scp root@mini2:/etc/nixos/hardware-configuration.nix nixos/machines/mini2/hardware-configuration.nix
colmena apply --on mini2
```

## Install / reinstall a machine (nixos-anywhere)

For machines with a defined `disko` layout (currently `laptop`):

```sh
# WIPES the target disk. Only run when you intend to reinstall.
nix run nixpkgs#nixos-anywhere -- \
  --flake .#laptop root@192.168.1.160
```

This partitions the disk (see `disko/laptop.nix`), installs NixOS, sets
the SSH key, and is fully repeatable. After install you're done — the
machine is under colmena control and future changes are just
`colmena apply`.

## Sanity checks before you push changes

```sh
nix flake check        # syntax + eval of all outputs
alejandra .            # auto-format (flake-wide)
```

## Next steps / ideas

- Secrets: add `sops-nix` (or `agenix`) to `modules/common.nix` and
  keep encrypted secrets in git, mirroring how Vault + External Secrets
  work for the k8s side.
- Add new k8s workers as NixOS machines here instead of hand-configuring
  them.
- The `laptop` machine needs its k8s-worker block filled in to rejoin
  the cluster after reinstall.