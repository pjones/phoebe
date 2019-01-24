# Configure monitoring and reporting services.
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.services.monitoring;

  plugins = import ./plugins.nix { inherit (pkgs) stdenvNoCC netdata; };

  alarmNotifyConf = pkgs.writeText "health_alarm_notify.conf"
    (optionalString cfg.pushover.enable ''
      SEND_PUSHOVER=YES
      PUSHOVER_APP_TOKEN="${cfg.pushover.apiKey}"
      DEFAULT_RECIPIENT_PUSHOVER="${concatStringsSep "," cfg.pushover.userKeys}"
    '');

  alarmConf = pkgs.writeText "alarms.conf" ''
    # Send alarms for systemd services.
      alarm: failed_service
         on: Services.status
         os: linux
      hosts: *
     lookup: min -1m unaligned
      every: 1m
       crit: $this < -3 && $this >= -4
       info: service is failed
         to: sysadmin
  '';
in
{
  #### Interface
  options.phoebe.services.monitoring = {
    enable = mkEnableOption "Monitoring and Reporting.";

    pushover = {
      enable = mkEnableOption "Alerts via Pushover.";
      apiKey = mkOption {
        type = types.str;
        example = "1234567890abcdefghijklmnopqrst";
        description = "Pushover API key for netdata";
      };
      userKeys = mkOption {
        type = types.listOf types.str;
        example = [ "1234567890abcdefghijklmnopqrst" ];
        description = "List of user keys.";
      };
    };
  };

  #### Implementation
  config = mkIf cfg.enable {
    # Enable systemd accounting:
    systemd.enableCgroupAccounting = true;

    # Use netdata to collect metrics:
    services.netdata = {
      enable = true;
      extraPluginPaths = [ "${plugins}/plugins.d" ];

      config.global = {
        "debug log"  = "syslog";
        "access log" = "syslog";
        "error log"  = "syslog";
      };

      config.plugins = {
        "phoebe.charts.d.plugin" = "yes";
      };
    };

    environment.etc."netdata/health_alarm_notify.conf" = {
      source = "${alarmNotifyConf}";
      mode   = "0444";
    };

    environment.etc."netdata/health.d/alarm.conf" = {
      source = "${alarmConf}";
      mode   = "0444";
    };
  };
}
