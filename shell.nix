let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  pkgs = import nixpkgs {
    config = {
      allowUnfree = true;
    };
  };
in

pkgs.mkShellNoCC {
  packages = with pkgs; [
    terraform
    helm
  ];
}
