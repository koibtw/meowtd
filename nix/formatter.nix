{
  treefmt,
  nixfmt,
  zig,
}:
treefmt.withConfig {
  runtimeInputs = [
    nixfmt
    zig
  ];
  settings = {
    on-unmatched = "info";
    tree-root-file = "flake.nix";
    formatter = {
      nixfmt = {
        command = "nixfmt";
        includes = [ "*.nix" ];
      };
      zigfmt = {
        command = "zig";
        options = [ "fmt" ];
        includes = [
          "*.zig"
          "*.zig.zon"
        ];
      };
    };
  };
}
