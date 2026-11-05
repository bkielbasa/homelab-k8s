#!/usr/bin/env bash
# Install NixOS on the laptop (192.168.1.160) via nixos-anywhere.
#
# WARNING: this WIPES /dev/sda on the laptop. Only run when intended.
# Run from a machine with Nix (e.g. mini2), NOT from the laptop itself.
#
# Prereqs:
#   - laptop drained & cordoned in the cluster (done)
#   - bklimczak has passwordless sudo on the laptop (verified)
#   - SSH key ~/.ssh/id_ed25519 (bklimczak@mini-pc) authorized on laptop

set -euo pipefail

TARGET_HOST="bklimczak@192.168.1.160"
FLAKE="github:bkielbasa/homelab-k8s#laptop"

nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
  --flake "${FLAKE}" \
  "${TARGET_HOST}"
