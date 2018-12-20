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

    ############################################################################
    # Things to disable when not using security settings:
    (mkIf (!cfg.enable) {
      # Only really useful for development VMs:
      networking.firewall.enable = false;
    })

    ############################################################################
    # Settings that are always enabled:
    {
      # Users must be created in Nix:
      users.mutableUsers = false;

      # Don't require or use any passwords:
      security.pam.enableSSHAgentAuth = true;
      services.openssh.passwordAuthentication = false;
      services.openssh.permitRootLogin = "without-password";
    }

    ############################################################################
    # Settings to enable when security is enabled:
    (mkIf cfg.enable {
      # Firewall:
      networking.firewall = {
        enable = true;
        allowPing = true;
        pingLimit = "--limit 1/minute --limit-burst 5";
        allowedTCPPorts = config.services.openssh.ports;
      };

      # SSH and authentication:
      services.openssh.forwardX11 = false;
      services.openssh.openFirewall = false; # Done above.

      # Run-time kernel modifications:
      # FIXME: enable after some testing.
      # security.lockKernelModules = true;
    })
  ];
}
