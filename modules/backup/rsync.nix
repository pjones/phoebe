# Hard-linked backups via rsync.
{ config, lib, pkgs, ...}: with lib;

let
  cfg = config.phoebe.backup.rsync;
  plib  = config.phoebe.lib;
  user = "backup";
  scripts = (import ../../pkgs/default.nix { inherit pkgs; }).backup-scripts;

  ##############################################################################
  # Backup options.
  backupOpts = {
    options = {
      host = mkOption {
        type = types.str;
        example = "example.com";
        description = "Host name for the machine to back up.";
      };

      port = mkOption {
        type = types.ints.positive;
        default = builtins.head config.services.openssh.ports;
        example = 22;
        description = "SSH port on the remote machine.";
      };

      user = mkOption {
        type = types.str;
        default = "backup";
        example = "root";
        description = "User name on the remote machine to use.";
      };

      directory = mkOption {
        type = types.path;
        default = "/var/backup";
        example = "/var/lib/backup";
        description = "Remote directory to sync to the local machine.";
      };

      key = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/home/backup/.ssh/id_ed25519";
        description = ''
          Optional SSH key to use when connecting to the remote
          machine.  If the key is provided by NixOps then this backup
          will wait until the key is available.
        '';
      };

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 02:00:00";
        example = "*-*-* *:00/30:00";
        description = ''
          A systemd calendar specification to designate the frequency
          of the backup.  You can use the "systemd-analyze calendar"
          command to validate your calendar specification.

          When increasing the frequency of the backups you should
          consider changing the number of backups that you keep.
        '';
      };

      keep = mkOption {
        type = types.ints.positive;
        default = 7;
        example = 14;
        description = "Number of backups to keep when deleting older backups.";
      };
    };
  };

  ##############################################################################
  # Sanitize the name of a directory.
  dir = path: replaceStrings ["/"] ["-"] (removePrefix "/" path);

  ##############################################################################
  # Generate a service/timer name (without the suffix):
  name = opts: "rsync-${opts.host}-${dir opts.directory}";

  ##############################################################################
  # Generate a systemd service for a backup.
  service = opts:
    let base = "${config.phoebe.backup.directory}/rsync";
        localdir = "${base}/${opts.host}/${dir opts.directory}";
    in rec {
      description = "rsync backup for ${opts.host}:${opts.directory}";
      path  = [ pkgs.coreutils scripts ];
      wants = plib.keyService opts.key;
      after = wants;

      serviceConfig = {
        Type = "simple";
        PermissionsStartOnly = "true";
        User = cfg.user;
      };

      preStart = ''
        mkdir -p "${localdir}"
        chown -R ${cfg.user}:${cfg.group} "${localdir}"
        chmod -R 0700 "${localdir}"
      '';

      script = ''
        export BACKUP_LIB_DIR=${scripts}/lib
        export BACKUP_LOG_DIR=stdout
        export BACKUP_SSH_KEY=${toString opts.key}
        export BACKUP_SSH_PORT=${toString opts.port}
        . "${scripts}/lib/backup.sh"
        backup_via_rsync "${opts.user}@${opts.host}:${opts.directory}" "${localdir}"
        backup-purge.sh -k "${toString opts.keep}" -d "${localdir}"
      '';
    };

  ##############################################################################
  # Generate a systemd timer for a backup.
  timer = opts: {
    description = "Scheduled Backup of ${opts.host}:${opts.directory}";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = opts.schedule;
    timerConfig.RandomizedDelaySec = "5m";
    timerConfig.Unit = "${name opts}.service";
  };

  ##############################################################################
  # Generate systemd services and timers.
  toSystemd = f: foldr (a: b: b // {"${name a}" = f a;}) {} cfg.schedules;

in
{
  #### Interface
  options.phoebe.backup.rsync = {
    enable = mkEnableOption "rsync backups";

    user = mkOption {
      type = types.str;
      default = user;
      description = "User to perform backups as.";
    };

    group = mkOption {
      type = types.str;
      default = config.phoebe.backup.user.group;
      description = "Group for the backup user.";
    };

    schedules = mkOption {
      type = types.listOf (types.submodule backupOpts);
      default = [];
      description = "List of backups to perform.";
    };
  };

  #### Implementation
  config = mkIf cfg.enable {
    phoebe.backup.user.enable = cfg.user == user;
    systemd.services = toSystemd service;
    systemd.timers   = toSystemd timer;
  };
}
