# Run any script to perform a backup.
{ config, lib, pkgs, ...}: with lib;

let
  cfg = config.phoebe.backup;
  plib  = config.phoebe.lib;

  ##############################################################################
  scriptOpts = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Unique name for this backup script.";
      };

      path = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "List of packages to put in PATH.";
      };

      script = mkOption {
        type = types.lines;
        description = "Script to run.";
      };

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 02:00:00";
        example = "*-*-* *:00/30:00";
        description = ''
          A systemd calendar specification to designate the frequency
          of the backup.  You can use the "systemd-analyze calendar"
          command to validate your calendar specification.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "backup";
        example = "root";
        description = "User to execute the script as.";
      };

      key = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/keys/mykey";
        description = ''
          Optional key file to wait for.  If the key is provided by
          NixOps then this backup will wait until the key is
          available.
        '';
      };

      services = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "foo.service" ];
        description = ''
          Extra services to require and wait for.  Useful if you want
          to require certain systemd mounts to exist.
        '';
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  ##############################################################################
  # Generate a systemd service for a backup.
  service = opts: rec {
    description = "${opts.name} backup";
    path  = [ pkgs.coreutils ] ++ opts.path;
    wants = plib.keyService opts.key ++ opts.services;
    after = wants;
    script = opts.script;
    serviceConfig.Type = "simple";
    serviceConfig.User = opts.user;
  };

  ##############################################################################
  # Generate a systemd timer for a backup.
  timer = opts: {
    description = "Scheduled ${opts.name} backup";
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = opts.schedule;
    timerConfig.RandomizedDelaySec = "5m";
    timerConfig.Unit = "backup-${opts.name}.service";
  };

  ##############################################################################
  # Generate systemd services and timers.
  toSystemd = f:
    foldr (a: b: b // {"backup-${a.name}" = f a;}) {}
          (attrValues cfg.scripts);

in
{
  #### Interface
  options.phoebe.backup.scripts = mkOption {
    type = types.attrsOf (types.submodule scriptOpts);
    default = { };

    example = {
      copy-files = {
        script = "cp ~/.config ~/.config.bk";
      };
    };

    description = "Set of backup scripts to run.";
  };

  #### Implementation
  config = {
    systemd.services = toSystemd service;
    systemd.timers   = toSystemd timer;
  };
}
