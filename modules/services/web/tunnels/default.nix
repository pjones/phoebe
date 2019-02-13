# Configure a host for restricted port forwarding.
{ config, lib, pkgs, ...}:

with lib;

let
  ##############################################################################
  cfg = config.phoebe.services.web.tunnels;

  ##############################################################################
  # Options for tunnels:
  tunnelOptions = {
    options = {
      subdomain = mkOption {
        type = types.str;
        example = "www";
        description = "Listen on port 443 of this subdomain.";
      };

      serverPort = mkOption {
        type = types.int;
        example = 3000;
        description = ''
          The port number on the server where SSH will be listening
          for connections.  This is the first component of the -R
          command to SSH.
        '';
      };
    };
  };

  ##############################################################################
  # Options for accounts:
  accountOptions = {
    options = {
      authorizedKey = mkOption {
        type = types.str;
        example = "ssh-ed25519 AAAAB3NzaC1k... alice@example.org";
        description = "SSH public key for this account.";
      };

      tunnels = mkOption {
        type = types.listOf (types.submodule tunnelOptions);
        example = [ { subdomain = "joe"; serverPort = 3000; } ];
        description = "List of HTTP tunnels to create.";
     };
    };
  };

  ##############################################################################
  # Create an authorized keys list:
  mkKey = account:
    let permitopen = t: ''permitlisten="*:${toString t.serverPort}"'';
        prefix = concatMapStringsSep "," permitopen account.tunnels;
    in "${prefix} ${account.authorizedKey}";

  ##############################################################################
  # Create an nginx virtual host for a tunnel account:
  virtualHost = account: tunnel: {
    "${tunnel.subdomain}.${cfg.hostName}" = {
      forceSSL = true;
      enableACME = true;
      root = "/var/empty";
      locations."/".proxyPass = "http://127.0.0.1:${toString tunnel.serverPort}";
    };
  };

  ##############################################################################
  # Create all virtual hosts for a given account:
  virtualHosts = account:
    foldr (a: b: recursiveUpdate b (virtualHost account a)) {} account.tunnels;

in
{
  #### Interface:
  options.phoebe.services.web.tunnels = {
    enable = mkEnableOption ''
      Enable HTTPS to HTTP private tunnels.  NOTE: This requires
      OpenSSH 7.8 or later which will be included in NixOS 19.03.

      This module enables a restricted user account that can be used
      with the "ssh -R" command to listen on server-side ports for
      incoming HTTP connections.  nginx is configured to forward
      incoming HTTPS connections on port 443 to these special SSH
      listening ports.

      This is useful for exposing an internal HTTP application as an
      external HTTPS application.  It's perfect for developing
      webhooks that need to be routed to developer machines.
    '';

    hostName = mkOption {
      type = types.str;
      example = "example.com";
      description = "Host name where all the subdomain tunnels are rooted.";
    };

    user = mkOption {
      type = types.str;
      default = "tunnel";
      description = "User account to create for SSH connections.";
    };

    accounts = mkOption {
      type = types.listOf (types.submodule accountOptions);
      description = "List of accounts to create tunnels for.";
    };
  };

  #### Interface:
  config = mkIf cfg.enable {
    # Services we'll be using:
    services.openssh.enable = true;

    # A user account for users to connect to.
    users.users."${cfg.user}" = {
      description = "HTTPS tunnel user";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = map mkKey cfg.accounts;
    };

    services.openssh.extraConfig = ''
      Match User ${cfg.user}
        AllowAgentForwarding no
        PermitTTY no
        PermitTunnel no
        PermitOpen none
        X11Forwarding no
        ForceCommand ${pkgs.shadow}/bin/nologin
      Match All
    '';

    # Configure a web server to reverse proxy connections to SSH:
    services.nginx = {
      enable = true;
      recommendedTlsSettings   = true;
      recommendedOptimisation  = true;
      recommendedGzipSettings  = true;
      recommendedProxySettings = true;
      virtualHosts = foldr (a: b: recursiveUpdate b (virtualHosts a)) {} cfg.accounts;
    };
  };
}
