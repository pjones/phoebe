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
  # Is PostgreSQL local?
  localpg = config.phoebe.services.postgresql.enable;

  ##############################################################################
  # Packages to put in the application's PATH.  FIXME:
  # propagatedBuildInputs won't always be set.
  appPath = app: [ app.package.rubyEnv ] ++ app.package.propagatedBuildInputs;

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
  # Generate a systemd service for a Ruby on Rails application:
  appService = app: {
    "rails-${app.name}" = {
      description = "${app.name} (Ruby on Rails)";
      path = appPath app;

      environment = {
        HOME = "${app.home}/home";
        RAILS_ENV = app.railsEnv;
        DATABASE_HOST = app.database.host;
        DATABASE_PORT = toString app.database.port;
        DATABASE_NAME = app.database.name;
        DATABASE_USER = app.database.user;
        DATABASE_PASSWORD_FILE = "${app.home}/state/database.password";
      } // app.environment;

      wantedBy = [ "multi-user.target" ];

      wants =
        plib.keyService app.database.passwordFile ++
        plib.keyService app.sourcedFile;

      after =
        [ "network.target" ] ++
        optional localpg  "postgresql.service" ++
        optional localpg  "pg-accounts.service" ++
        plib.keyService app.database.passwordFile ++
        plib.keyService app.sourcedFile;

      preStart = ''
        # Prepare the config directory:
        rm -rf ${app.home}/config
        mkdir -p ${app.home}/{config,log,tmp,db,state}

        cp -rf ${app.package}/share/${app.name}/config.dist/* ${app.home}/config/
        cp ${app.package}/share/${app.name}/db/schema.rb.dist ${app.home}/db/schema.rb
        cp ${./database.yml} ${app.home}/config/database.yml
        cp ${app.database.passwordFile} ${app.home}/state/database.password

        mkdir -p ${app.home}/home
        ln -nfs ${app.package}/share/${app.name} ${app.home}/home/${app.name}

        # Copy the sourcedFile if necessary:
        ${optionalString (app.sourcedFile != null) ''
          cp ${app.sourcedFile} ${app.home}/state/sourcedFile.sh
        ''}

        # Fix permissions:
        chown -R rails-${app.name}:rails-${app.name} ${app.home}
        chmod go+rx $(dirname "${app.home}")
        chmod u+w ${app.home}/db/schema.rb

      '' + optionalString app.database.migrate ''
        # Migrate the database (use sudo so environment variables go through):
        ${pkgs.sudo}/bin/sudo -u rails-${app.name} -EH \
          ${scripts}/bin/db-migrate.sh \
            -r ${app.package}/share/${app.name} \
            -s ${app.home}/state
      '';

      script = ''
        ${optionalString (app.sourcedFile != null) ". ${app.home}/state/sourcedFile.sh"}
        ${app.package.rubyEnv}/bin/puma -e ${app.railsEnv} -p ${toString app.port}
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

    # Each application gets a systemd service to keep it running.
    systemd.services = collectApps appService;
  };
}
