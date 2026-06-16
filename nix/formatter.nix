{
  treefmt,
  nixfmt,
  shfmt,
  zig,
}:
treefmt.withConfig {
  runtimeInputs = [
    nixfmt
    shfmt
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
      shfmt = {
        command = "shfmt";
        options = [
          "-i=2"
          "-w"
        ];
        includes = [ "*.sh" ];
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
