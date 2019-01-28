# Extra configuration for nginx:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  ##############################################################################
  # Save some typing.
  cfg = config.phoebe.services.nginx;

in
{
  #### Interface
  options.phoebe.services.nginx = {
    syslog = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to send nginx logging to syslog/journald.

        This option only applies if nginx is enabled.
      '';
    };
  };

  #### Implementation
  config = mkMerge [
    (mkIf (config.services.nginx.enable && cfg.syslog) {
      services.nginx.commonHttpConfig = ''
        access_log syslog:server=unix:/dev/log;
        error_log syslog:server=unix:/dev/log;
      '';
    })
  ];
}
