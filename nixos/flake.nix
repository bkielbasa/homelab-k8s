{
  description = "Homelab NixOS machines (managed with colmena)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    colmena.url = "github:zhaofengli/colmena";
    disko.url = "github:nix-community/disko";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
  };

  outputs =
    { self, nixpkgs, colmena, disko, nixos-anywhere, ... }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;
    in
    {
      # ------------------------------------------------------------------
      # colmena: declarative deployment of *running* systems.
      #
      #   nix develop                 # enter a shell with colmena + friends
      #   colmena apply               # apply to every host
      #   colmena apply --on laptop   # apply to a single host
      #   colmena apply-local         # apply to the machine you are on
      # ------------------------------------------------------------------
      colmena = {
        meta = {
          # colmena expects an evaluated pkgs instance here.
          nixpkgs = import nixpkgs { inherit system; };
          # Build on this (control) machine, distribute the result to the
          # nodes. Avoids needing nix installed on each node.
          specialArgs = { inherit inputs; };
        };

        hostDefaults.modules = [ ./modules/common.nix ];

        laptop = {
          imports = [ ./machines/laptop.nix ];
          deployment.targetHost = "192.168.1.160"; # static IP on the LAN
          deployment.targetUser = "root";
        };

        mini2 = {
          imports = [ ./machines/mini2.nix ];
          deployment.targetHost = "192.168.1.226";
          deployment.targetUser = "root";
        };
      };

      # ------------------------------------------------------------------
      # nixosConfigurations: `nixos-anywhere` bootstrap of fresh machines.
      #
      #   nix run nixpkgs#nixos-anywhere -- \
      #     --flake .#laptop root@192.168.1.160
      # ------------------------------------------------------------------
      nixosConfigurations = {
        laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./machines/laptop.nix ];
          specialArgs = { inherit inputs; };
        };
        mini2 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./machines/mini2.nix ];
          specialArgs = { inherit inputs; };
        };
      };

      # ------------------------------------------------------------------
      # devShell: one command to get the tooling, no global install needed.
      # ------------------------------------------------------------------
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = [
          nixpkgs.legacyPackages.${system}.colmena
          nixpkgs.legacyPackages.${system}.nixos-anywhere
          nixpkgs.legacyPackages.${system}.disko
          nixpkgs.legacyPackages.${system}.nixpkgs-fmt
          nixpkgs.legacyPackages.${system}.alejandra # preferred formatter, run: alejandra .
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
    };
}