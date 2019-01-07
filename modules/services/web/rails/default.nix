# Configure Ruby on Rails applications:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  ##############################################################################
  # Save some typing.
  cfg = config.phoebe.services.rails;
  plib = config.phoebe.lib;
  scripts = import ./scripts.nix { inherit lib pkgs; };
  options = import ./options.nix { inherit config lib pkgs; };

  ##############################################################################
  # The main Rails service:
  mainService = app: {
    name = "main";
    schedule = null;
    isMain = true;

    script = ''
      puma -e ${app.railsEnv} -p ${toString app.port}
    '';
  };

  ##############################################################################
  # Is PostgreSQL local?
  localpg = config.phoebe.services.postgresql.enable;

  ##############################################################################
  # Packages to put in the application's PATH.  FIXME:
  # propagatedBuildInputs won't always be set.
  appPath = app: [ app.package.rubyEnv ] ++ app.package.propagatedBuildInputs;

  ##############################################################################
  # All of the environment variables that a Rails app needs:
  appEnv = app: {
    HOME = "${app.home}/home";
    RAILS_ENV = app.railsEnv;
    DATABASE_HOST = app.database.host;
    DATABASE_PORT = toString app.database.port;
    DATABASE_NAME = app.database.name;
    DATABASE_USER = app.database.user;
    DATABASE_PASSWORD_FILE = "${app.home}/state/database.password";
  } // app.environment;

  ##############################################################################
  # Collect all apps into a single set using the given function:
  collectApps = f: foldr (a: b: recursiveUpdate b (f a)) {} (attrValues cfg.apps);

  ##############################################################################
  # Generate an NGINX configuration for an application:
  appToVirtualHost = app: {
    "${app.domain}" = {
      forceSSL = config.phoebe.security.enable;
      enableACME = config.phoebe.security.enable;
      root = "${app.package}/share/${app.name}/public";

      locations = {
        "/assets/" = {
          extraConfig = ''
            gzip_static on;
            expires 1M;
            add_header Cache-Control public;
          '';
        };

        "/" = {
          tryFiles = "$uri @app";
        };

        "@app" = {
          proxyPass = "http://localhost:${toString app.port}";
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
  # Generate a systemd service for a Ruby on Rails application:
  appService = app: service: {
    "rails-${app.name}-${service.name}" = {
      description = "${app.name} (Ruby on Rails) ${service.name}";
      path = appPath app;
      environment = appEnv app;

      # Only start this service if it isn't scheduled by a timer.
      wantedBy = optional (service.schedule == null) "multi-user.target";

      wants =
        plib.keyService app.database.passwordFile ++
        plib.keyService app.sourcedFile;

      after =
        [ "network.target" ] ++
        optional localpg  "postgresql.service" ++
        optional localpg  "pg-accounts.service" ++
        optional (!service.isMain) "rails-${app.name}-main" ++
        plib.keyService app.database.passwordFile ++
        plib.keyService app.sourcedFile;

      preStart = optionalString service.isMain ''
        # Prepare the config directory:
        rm -rf ${app.home}/config
        mkdir -p ${app.home}/{config,log,tmp,db,state}

        cp -rf ${app.package}/share/${app.name}/config.dist/* ${app.home}/config/
        cp ${app.package}/share/${app.name}/db/schema.rb.dist ${app.home}/db/schema.rb
        cp ${./database.yml} ${app.home}/config/database.yml
        cp ${app.database.passwordFile} ${app.home}/state/database.password

        # Additional set up for the home directory:
        mkdir -p ${app.home}/home
        ln -nfs ${app.package}/share/${app.name} ${app.home}/home/${app.name}
        ln -nfs ${plib.attrsToShellExports "rails-${app.name}-env" (appEnv app)} ${app.home}/home/.env
        cp ${./profile.sh} ${app.home}/home/.profile
        chmod 0700 ${app.home}/home/.profile

        # Copy the sourcedFile if necessary:
        ${optionalString (app.sourcedFile != null) ''
          cp ${app.sourcedFile} ${app.home}/state/sourcedFile.sh
        ''}

        # Fix permissions:
        chown -R rails-${app.name}:rails-${app.name} ${app.home}
        chmod go+rx $(dirname "${app.home}")
        chmod u+w ${app.home}/db/schema.rb

      '' + optionalString (service.isMain && app.database.migrate) ''
        # Migrate the database:
        ${pkgs.sudo}/bin/sudo --user=rails-${app.name} --login \
          ${scripts}/bin/db-migrate.sh \
            -r ${app.package}/share/${app.name} \
            -s ${app.home}/state
      '';

      script = ''
        ${optionalString (app.sourcedFile != null) ". ${app.home}/state/sourcedFile.sh"}
        ${service.script}
      '';

      serviceConfig = {
        WorkingDirectory = "${app.package}/share/${app.name}";
        Restart = "on-failure";
        TimeoutSec = "infinity"; # FIXME: what's a reasonable amount of time?
        Type = "simple";
        PermissionsStartOnly = true;
        User = "rails-${app.name}";
        Group = "rails-${app.name}";
        UMask = "0077";
      };
    };
  };

  ##############################################################################
  # Schedule some services with a systemd timer:
  appTimer = app: service: optionalAttrs (service.schedule != null) {
    "rails-${app.name}-${service.name}" = {
      description = "${app.name} (Ruby on Rails) ${service.name}";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = service.schedule;
      timerConfig.Unit = "rails-${app.name}-${service.name}.service";
    };
  };

  ##############################################################################
  # Collect all services for a given application and turn them into
  # systemd services.
  appServices = app:
    foldr (service: set: recursiveUpdate set (appService app service)) {}
          ( [(mainService app)] ++ attrValues app.services );

  ##############################################################################
  # Collect all services and turn them into systemd timers:
  appTimers = app:
    foldr (service: set: recursiveUpdate set (appTimer app service)) {}
          (attrValues app.services);

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
      packages = appPath app;
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
    # running.
    systemd.services = collectApps appServices;
    systemd.timers   = collectApps appTimers;

    # Rotate all of the log files:
    services.logrotate = {
      enable = true;
      config = concatMapStringsSep "\n" appLogRotation (attrValues cfg.apps);
    };
  };
}
