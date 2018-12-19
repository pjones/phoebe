{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.security;

in
{
  #### Interface
  options.phoebe.security = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether or not to enable security settings.  Usually this will
        be left at the default value of true.  However, for testing
        inside virtual machines you probably wnat to turn this off.
      '';
    };
  };

  #### Implementation
  config = mkMerge [
    (mkIf (!cfg.enable) {
      # Only really useful for development VMs:
      networking.firewall.enable = false;
    })

    (mkIf cfg.enable {
      # Firewall:
      networking.firewall = {
        enable = true;
        allowPing = true;
        pingLimit = "--limit 1/minute --limit-burst 5";
        allowedTCPPorts = config.services.openssh.ports;
      };
    })
  ];
}
