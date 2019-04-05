# Configure Ruby on Rails applications:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  ##############################################################################
  # Save some typing.
  cfg = config.phoebe.services.rails;

  ##############################################################################
  options    = import ./options.nix { inherit config lib pkgs; };
  appSystemd = import ./systemd.nix { inherit config pkgs lib; };
  funcs      = import ./functions.nix { inherit config; };
  scripts    = import ./scripts.nix { inherit lib pkgs; };

  ##############################################################################
  # Collect all apps into a single set using the given function:
  collectApps = f: foldr (a: b: recursiveUpdate b (f a)) {} (attrValues cfg.apps);

  ##############################################################################
  # Generate an NGINX configuration for an application:
  appToVirtualHost = app: {
    "${app.domain}" = {
      forceSSL = config.phoebe.security.enable;
      enableACME = config.phoebe.security.enable;
      root = "${funcs.appLink app}/share/${app.name}/public";

      locations = {
        "/assets/" = {
          extraConfig = ''
            gzip_static on;
            expires 1M;
            add_header Cache-Control public;
          '';
        };

        "/" = {
          tryFiles = "$uri @rails-${app.name}";
        };

        "@rails-${app.name}" = {
          proxyPass = "http://127.0.0.1:${toString app.port}";
        };
      };
    };
  };

  ##############################################################################
  # Log rotation:
  appLogRotation = app:
    ''
      ${app.home}/log/*.log {
        size 64M
        rotate 16
        missingok
        compress
        delaycompress
        notifempty
        copytruncate
      }
    '';

  ##############################################################################
  # Generate a user account for a Ruby on Rails application:
  appUser = app: {
    users."rails-${app.name}" = {
      description = "${app.name} Ruby on Rails Application";
      home = "${app.home}/home";
      createHome = true;
      group = "rails-${app.name}";
      shell = "${pkgs.bash}/bin/bash";
      extraGroups = [ config.services.nginx.group ];
      packages = funcs.appPath app;
    };
    groups."rails-${app.name}" = {};
  };

in
{
  #### Interface
  options.phoebe.services.rails = {
    apps = mkOption {
      type = types.attrsOf (types.submodule options.application);
      default = { };
      description = "Rails applications to configure.";
    };
  };

  #### Implementation
  config = mkIf (length (attrValues cfg.apps) != 0) {
    # Use NGINX to proxy requests to the apps:
    services.nginx = {
      enable = true;
      recommendedTlsSettings   = config.phoebe.security.enable;
      recommendedOptimisation  = true;
      recommendedGzipSettings  = true;
      recommendedProxySettings = true;
      virtualHosts = collectApps appToVirtualHost;
    };

    # Each application gets a user account:
    users = collectApps appUser;

    # Each application gets one or more systemd services to keep it
    # running.  There's also a systemd target and some timers.
    systemd = collectApps appSystemd;

    # Rotate all of the log files:
    services.logrotate = {
      enable = true;
      config = concatMapStringsSep "\n" appLogRotation (attrValues cfg.apps);
    };

    # Additional packages to install in the environment:
    environment.systemPackages = [
      scripts.system
    ];
  };
}
