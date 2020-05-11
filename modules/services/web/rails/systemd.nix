{ config
, pkgs
, lib
}:

with lib;

let

  ##############################################################################
  # Helpful functions.
  plib  = pkgs.phoebe.lib;
  funcs = import ./functions.nix;
  scripts = import ./scripts.nix { inherit lib pkgs; };

  ##############################################################################
  # Is PostgreSQL local?
  localpg = config.phoebe.services.postgresql.enable;

  ##############################################################################
  # The main Rails service:
  mainService = app: {
    name = "main";
    schedule = null;
    isMain = true;
    isMigration = false;

    script = ''
      puma -e ${app.railsEnv} -p ${toString app.port}
    '';
  };

  ##############################################################################
  # The database migration service:
  migrationService = app: {
    name = "migrations";
    schedule = null;
    isMain = false;
    isMigration = true;

    script = ''
      ${scripts.user}/bin/db-migrate.sh \
        -r ${funcs.appLink app}/share/${app.name} \
        -s ${app.home}/state
    '';
  };

  ##############################################################################
  # Generate a systemd service for a Ruby on Rails application:
  appService = app: service: {
    "rails-${app.name}-${service.name}" = {
      description = "${app.name} (Ruby on Rails) ${service.name}";
      path = with pkgs; [ coreutils nix ];
      environment = funcs.appEnv app;

      # Only start this service if it isn't scheduled by a timer.
      partOf   = optional (service.schedule == null) "rails-${app.name}.target";
      wantedBy = optional (service.schedule == null) "rails-${app.name}.target";

      wants = plib.keys.keyService app.database.passwordFile
        ++ plib.keys.keyService app.sourcedFile
        ++ app.afterServices
        ++ optional (!service.isMigration && app.database.migrate) "rails-${app.name}-migrations"
        ++ optional (!service.isMain && !service.isMigration) "rails-${app.name}-main";

      after = [ "network.target" ]
        ++ optional localpg  "postgresql.service"
        ++ optional localpg  "postgres-account-manager.service"
        ++ plib.keys.keyService app.database.passwordFile
        ++ plib.keys.keyService app.sourcedFile
        ++ app.afterServices
        ++ optional (!service.isMigration && app.database.migrate) "rails-${app.name}-migrations"
        ++ optional (!service.isMain && !service.isMigration) "rails-${app.name}-main";

      preStart = optionalString (service.isMain || service.isMigration) ''
        # Link the package into the application's home directory:
        if [ ! -e "${funcs.appLink app}" ] || [ -z "${toString app.deployedExternally}" ]; then
          ln -nfs "${app.package}" "${funcs.appLink app}"
        fi

        # Prepare the config directory:
        rm -rf ${app.home}/config
        mkdir -p ${app.home}/{config,log,tmp,db,state}
        cp -rf ${funcs.appLink app}/share/${app.name}/config.dist/* ${app.home}/config/
        cp -f ${funcs.appLink app}/share/${app.name}/db/schema.rb.dist ${app.home}/db/schema.rb
        cp -f ${./database.yml} ${app.home}/config/database.yml
        cp -f ${app.database.passwordFile} ${app.home}/state/database.password

        # Additional set up for the home directory:
        mkdir -p ${app.home}/home
        ln -nfs ${funcs.appLink app}/share/${app.name} ${app.home}/home/app
        ln -nfs ${plib.shell.attrsToShellExports "rails-${app.name}-env" (funcs.appEnv app)} ${app.home}/home/.env
        echo 'eval $(${scripts.user}/bin/build-path.sh "${funcs.appLink app}")' > ${app.home}/home/.path
        cp ${./profile.sh} ${app.home}/home/.profile
        chmod 0700 ${app.home}/home/.profile

        # Copy the sourcedFile if necessary:
        ${optionalString (app.sourcedFile != null) ''
          cp -f ${app.sourcedFile} ${app.home}/state/sourcedFile.sh
        ''}

        # Fix permissions:
        chown -R rails-${app.name}:rails-${app.name} ${app.home}
        chmod go+rx $(dirname "${app.home}") "${app.home}"
        chmod u+w ${app.home}/db/schema.rb
      '';

      script = ''
        ${optionalString (app.sourcedFile != null) ". ${app.home}/state/sourcedFile.sh"}
        eval $(${scripts.user}/bin/build-path.sh "${funcs.appLink app}")
        ${service.script}
      '';

      serviceConfig = {
        WorkingDirectory = "-${funcs.appLink app}/share/${app.name}";
        Type = if service.isMigration then "oneshot" else "simple";
        Restart = if service.isMigration then "no" else "on-failure";
        TimeoutSec = "infinity"; # FIXME: what's a reasonable amount of time?
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
      ( singleton (mainService app)
        ++ optional app.database.migrate (migrationService app)
        ++ attrValues app.services );

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
