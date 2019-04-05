{ config, lib, pkgs, ...}:

with lib;

let
  ##############################################################################
  functions = import ./functions.nix { inherit config; };

  ##############################################################################
  # Database configuration:
  database = {
    options = {
      name = mkOption {
        type = types.str;
        example = "marketing";
        description = "Database name.";
      };

      user = mkOption {
        type = types.str;
        example = "jdoe";
        description = "Database user name.";
      };

      passwordFile = mkOption {
        type = types.path;
        example = "/run/keys/db-password";
        description = ''
          A file containing the database password.  This allows you to
          deploy a password with NixOps.
        '';
      };

      migrate = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = "Whether or not database migrations should run on start.";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Host name for the database server.";
      };

      port = mkOption {
        type = types.int;
        default = config.services.postgresql.port;
        description = "Port number for the database server";
      };
    };
  };

  ##############################################################################
  # Service configuration:
  service = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        example = "sidekiq";
        description = "The name of the additional service to run.";
      };

      script = mkOption {
        type = types.lines;
        example = "sidekiq -c 5 -v -q default";
        description = "Shell commands executed as the service's main process.";
      };

      schedule = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "*-*-* *:00/5:00";
        description = ''
          If null (the default), run this service in the background
          continuously, restarting it if it stops.  However, if this
          option is set, it should be a systemd calendar string and
          this service will run on a scheduled timer instead.
        '';
      };

      isMain = mkOption {
        internal = true;
        type = types.bool;
        default = false;
        description = "Is this the main Rails process?";
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  ##############################################################################
  # Application configuration:
  application = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "The name of the Ruby on Rails application.";
      };

      enable = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = ''
          Whether to enable this application by default.

          Setting this value to false will prevent any of the systemd
          services from starting.  This is useful for creating
          development environments where everything is set up but
          nothing is running.
        '';
      };

      deployedExternally = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          When true, system activation will not override the app link
          in the home directory.  However, it will be created if missing.

          This is useful if you want to deploy your Rails application
          using some external tool.  In the Phoebe scripts directory
          there is an example script for deploying with
          nix-copy-closure.
        '';
      };

      home = mkOption {
        type = types.path;
        description = "The directory where the application is deployed to.";
      };

      domain = mkOption {
        type = types.str;
        default = null;
        description = "The FQDN to use for this application.";
      };

      port = mkOption {
        type = types.int;
        default = null;
        description = "The port number to forward requests to.";
      };

      package = mkOption {
        type = types.package;
        description = "The derivation for the Ruby on Rails application.";
      };

      database = mkOption {
        type = types.submodule database;
        description = "Database configuration.";
      };

      services = mkOption {
        type = types.attrsOf (types.submodule service);
        default = { };
        description = ''
          Additional services to run for this Rails application.  For
          example, if you need to have background queue processing
          scripts running this is where you'd want to do that.

          All of the listed services are run via systemd and are
          executed in the same environment as the main Rails
          application itself.
        '';
      };

      railsEnv = mkOption {
        type = types.str;
        default = "production";
        example = "development";
        description = "What to use for RAILS_ENV.";
      };

      environment = mkOption {
        type = types.attrs;
        default = { };
        description = "Environment variables.";
      };

      sourcedFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/keys/env.sh";
        description = ''
          Bash file to source immediately before running any service
          command.

          If the file is store under /run/keys the service will wait
          for the file to become available.

          This option can be used to set environment variables more
          securely than using the environment option.  However, you
          should really use the Rails secrets system.
        '';
      };

      afterServices = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "foo-key.service" ];
        description = "Additional services to start before Rails.";
      };
    };

    config = {
      name = mkDefault name;
      home = mkDefault (functions.home name);
    };
  };

in { inherit database application; }
