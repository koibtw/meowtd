{
  description = "meowtd";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems = f: lib.genAttrs lib.systems.flakeExposed (s: f nixpkgs.legacyPackages.${s});
    in
    {
      nixosModules.default = ./nix/os-module.nix;
      homeManagerModules.default = ./nix/hm-module.nix;

      packages = forAllSystems (pkgs: {
        meowtd = pkgs.callPackage ./nix/packages/send.nix { };
        meowtd-receive = pkgs.callPackage ./nix/packages/receive.nix { };
      });

      formatter = forAllSystems (pkgs: pkgs.callPackage ./nix/formatter.nix { });
      devShells = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/shell.nix { };
      });
    };
}
