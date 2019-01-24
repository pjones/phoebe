{ config
, pkgs
, lib
}:

with lib;

let

  ##############################################################################
  # Helpful functions.
  plib  = config.phoebe.lib;
  funcs = import ./functions.nix { inherit config; };
  scripts = import ./scripts.nix { inherit lib pkgs; };

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
  # Generate a systemd service for a Ruby on Rails application:
  appService = app: service: {
    "rails-${app.name}-${service.name}" = {
      description = "${app.name} (Ruby on Rails) ${service.name}";
      path = funcs.appPath app;
      environment = funcs.appEnv app;

      # Only start this service if it isn't scheduled by a timer.
      partOf   = optional (service.schedule == null) "rails-${app.name}.target";
      wantedBy = optional (service.schedule == null) "rails-${app.name}.target";

      wants =
        plib.keyService app.database.passwordFile ++
        plib.keyService app.sourcedFile;

      after =
        [ "network.target" ] ++
        optional funcs.localpg  "postgresql.service" ++
        optional funcs.localpg  "pg-accounts.service" ++
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
        ln -nfs ${plib.attrsToShellExports "rails-${app.name}-env" (funcs.appEnv app)} ${app.home}/home/.env
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
      wantedBy = optional app.enable "timers.target";
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
  # All systemd settings for an application:
  appSystemd = app: {
    targets."rails-${app.name}" = {
      description = "${app.name} (Ruby on Rails)";
      wantedBy = optional app.enable "multi-user.target";
    };

    services = appServices app;
    timers   = appTimers app;
  };

in appSystemd
