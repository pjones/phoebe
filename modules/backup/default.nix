{ config, lib, pkgs, ...}: with lib;

let
  cfg = config.phoebe.backup;
  user = "backup";
in
{
  imports = [
    ./postgresql.nix
    ./rsync.nix
  ];

  #### Interface
  options.phoebe.backup = {
    user = {
      enable = mkEnableOption "Backup user and group.";

      name = mkOption {
        type = types.str;
        default = user;
        description = "User to perform backups as.";
      };

      group = mkOption {
        type = types.str;
        default = user;
        description = "Group for the backup user.";
      };
    };

    directory = mkOption {
      type = types.path;
      default = "/var/backup";
      description = ''
        Base directory where backups will be stored.  Each host to
        back up will get a directory under this base directory.
      '';
    };
  };

  #### Implementation
  config = mkIf cfg.user.enable {
    users.users."${cfg.user.name}" = {
      description = "Backup user.";
      home = cfg.directory;
      createHome = true;
      group = cfg.user.group;
      isSystemUser = true;
    };

    users.groups."${cfg.user.group}" = {};
  };
}
