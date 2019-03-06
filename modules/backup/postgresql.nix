# Simple backups for PostgreSQL.
{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.phoebe.backup.postgresql;
  scripts = (import ../../pkgs/default.nix { inherit pkgs; }).backup-scripts;
  pguser = "postgres";

  # systemd service:
  service = database: {
    "backup-postgresql-${database}" = {
      description = "Backup PostgreSQL Database ${database}";
      after = [ "postgresql.service" ];
      path  = [ pkgs.coreutils config.services.postgresql.package scripts ];

      serviceConfig = {
        Type = "simple";
        PermissionsStartOnly = "true";
        User = pguser;
      };

      preStart = ''
        mkdir -p "${cfg.directory}"
        chown ${pguser}:${pguser} "${cfg.directory}"
        chmod 0750 "${cfg.directory}"
      '';

      script = ''
        export BACKUP_DIRECTORY="${cfg.directory}"
        export BACKUP_LOG_DIR=stdout
        backup-postgresql-dump.sh "${database}"
        backup-purge.sh -k ${toString cfg.keep} "${cfg.directory}/${database}"
      '';
    };
  };

  # systemd timer:
  timer = database: {
    "backup-postgresql-${database}" = {
      description = "Scheduled Backup of PostgreSQL ${database}";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = cfg.schedule;
      timerConfig.RandomizedDelaySec = "5m";
      timerConfig.Unit = "backup-postgresql-${database}.service";
    };
  };

in
{
  #### Interface
  options.phoebe.backup.postgresql = {
    enable = mkEnableOption "Backup PostgreSQL Databases.";

    databases = mkOption {
      type = types.nonEmptyListOf types.str;
      example = [ "store" ];
      description = "Database names to backup.";
    };

    directory = mkOption {
      type = types.path;
      default = "/var/backup/postgresql";
      description = "Base directory where dumps are stored.";
    };

    schedule = mkOption {
      type = types.str;
      default = "*-*-* 00/2:00:00";
      description = "A systemd OnCalendar formatted frequency specification.";
    };

    keep = mkOption {
      type = types.ints.positive;
      default = 12;
      description = "Number of backups to keep when deleting older backups.";
    };
  };

  #### Implementation
  config = mkIf cfg.enable {
    # Configure systemd services and timers:
    systemd.services = foldr (a: b: service a // b) {} cfg.databases;
    systemd.timers   = foldr (a: b: timer   a // b) {} cfg.databases;
  };
}
