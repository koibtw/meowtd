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
      devShells = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/shell.nix { };
      });
      formatter = forAllSystems (pkgs: pkgs.callPackage ./nix/formatter.nix { });
    };
}
