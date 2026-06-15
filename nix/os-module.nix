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
    escapeShellArg
    concatStringsSep
    ;

  cfg = config.services.meowtd;
in
{
  options.services.meowtd = {
    enable = mkEnableOption "meowtd";

    file = mkOption {
      type = types.str;
      default = "/etc/motd";
      description = "absolute path to the motd file to update";
    };

    maxLength = mkOption {
      type = types.int;
      default = 1024;
      example = 512;
      description = "maximum allowed message length (0 for unlimited)";
    };

    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "public ssh keys authorized to use meowtd";
    };

    user = mkOption {
      type = types.str;
      default = "meowtd";
      description = ''
        system user for meowtd.
        if this is changed, the client needs to be configured appropriately
      '';
    };

    group = mkOption {
      type = types.str;
      default = "meowtd";
      description = "group for the meowtd user";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./packages/receive.nix { };
      description = "the meowtd package";
    };
  };

  config = mkIf cfg.enable {
    users = {
      motdFile = cfg.file;

      groups.${cfg.group} = { };
      users.${cfg.user} = {
        inherit (cfg) group;
        isSystemUser = true;
        shell = pkgs.runtimeShell;

        openssh.authorizedKeys.keys = map (key: ''
          command="${
            concatStringsSep " " [
              "MEOWTD_PATH=${escapeShellArg cfg.file}"
              "MEOWTD_MAX_LENGTH=${toString cfg.maxLength}"
              "exec ${cfg.package}/bin/meowtd-receive"
            ]
          }",restrict ${key}
        '') cfg.authorizedKeys;
      };
    };

    systemd.tmpfiles.rules = [ "f ${cfg.file} 0664 root ${cfg.group} -" ];

    assertions = [
      {
        assertion = config.services.openssh.enable;
        message = "meowtd requires openssh";
      }
    ];
  };
}
