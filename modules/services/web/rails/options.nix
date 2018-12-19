{ config, lib, pkgs, ...}:

with lib;

let
  ##############################################################################
  functions = import ./functions.nix;

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

      passwordService = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "db-password.service";
        description = ''
          A service to wait on before starting the Rails application.
          This service should provide the password file for the
          passwordFile option.  Useful when deploying passwords with
          NixOps.
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
  # Application configuration:
  application = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "The name of the Ruby on Rails application.";
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
    };

    config = {
      name = mkDefault name;
      home = mkDefault (functions.home name);
    };
  };

in { inherit database application; }
