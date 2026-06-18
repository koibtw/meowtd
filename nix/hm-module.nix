{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkOption
    mkEnableOption
    literalExpression
    ;

  json = pkgs.formats.json { };
  cfg = config.programs.meowtd;
in
{
  options.programs.meowtd = {
    enable = mkEnableOption "meowtd client";

    settings = mkOption {
      inherit (json) type;
      default = { };
      example = literalExpression ''
        address = "your-ip-or-hostname";
        auth.key.private = "/path/to/your/ssh_key";
      '';
      description = ''
        configuration written to {file}`$XDG_CONFIG_HOME/meowtd/config.json`

        see <https://git.koi.rip/koi/meowtd#client-configuration> for details
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./packages/send.nix { };
      description = "the meowtd package";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
    xdg.configFile."meowtd/config.json" = mkIf (cfg.settings != { }) {
      source = json.generate "meowtd-config.json" cfg.settings;
    };
  };
}
