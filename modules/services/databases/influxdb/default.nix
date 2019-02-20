# Configure InfluxDB:
{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.phoebe.services.influxdb;
  plib = config.phoebe.lib;
  scripts = import ./scripts.nix { inherit config lib pkgs; };
  usernameRe = "^[a-zA-Z0-9_-]+$";

  ##############################################################################
  # User accounts:
  account = { name, ... }: {
    options = {
      name = mkOption {
        type = types.strMatching usernameRe;
        example = "jdoe";
        description = "Username for the accout.";
      };

      passwordFile = mkOption {
        type = types.path;
        example = "/run/keys/influxdb-jdoe";
        description = ''
          File containing the account password.  Note that the
          password may not contain single quotes.  If any single
          quotes are present they will be silently removed.
        '';
      };

      isAdmin = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "Whether to grant full admin rights to this user.";
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  ##############################################################################
  # Privileges:
  privilege = { name, ...}: {
    options = {
      user = mkOption {
        type = types.strMatching usernameRe;
        example = "jdoe";
        description = "User to grant privileges to.";
      };

      access = mkOption {
        type = types.enum [ "READ" "WRITE" "ALL" ];
        example = "read";
        description = "Grant privilege.  One of READ, WRITE, or ALL.";
      };
    };

    config = {
      user = mkDefault name;
    };
  };

  ##############################################################################
  # Databases:
  database = { name, ... }: {
    options = {
      name = mkOption {
        type = types.strMatching usernameRe;
        example = "my_database";
        description = "Database name.";
      };

      privileges = mkOption {
        type = types.attrsOf (types.submodule privilege);
        default = { };
        description = "Privileges to grant for this database.";
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  ##############################################################################
  # Create missing users:
  createuser = name: file: isadmin: ''
    ${scripts}/bin/createuser.sh "${name}" "${file}" "${toString isadmin}"
  '';

  ##############################################################################
  # Create a missing database:
  createdb = database: ''
    ${scripts}/bin/createdb.sh "${database.name}"
    ${concatMapStringsSep "\n" (p: creategrant p.user database.name p.access)
      (attrValues database.privileges)}
  '';

  ##############################################################################
  # Create missing grants:
  creategrant = name: database: priv:
    optionalString (cfg.accounts ? "${name}") ''
      ${scripts}/bin/creategrant.sh "${name}" "${database}" "${priv}"
    '';

  ##############################################################################
  # A list of services that need to be waited on for keys:
  keyservices =
    optionals cfg.auth.enable (plib.keyService cfg.superuser.passwordFile) ++
    concatMap (a: plib.keyService a.passwordFile) (attrValues cfg.accounts);

in
{
  #### Interface:
  options.phoebe.services.influxdb = {
    enable = mkEnableOption "InfluxDB";
    auth.enable = mkEnableOption "Authentication.";

    superuser.name = mkOption {
      type = types.strMatching usernameRe;
      default = config.services.influxdb.user;
      example = "root";
      description = "The name of the InfluxDB internal admin user.";
    };

    superuser.passwordFile = mkOption {
      type = types.path;
      example = "/run/keys/influxdb-superuser";
      description = "File holding the InfluxDB internal admin password.";
    };

    accounts = mkOption {
      type = types.attrsOf (types.submodule account);
      default = { };
      description = "User accounts.";
    };

    databases = mkOption {
      type = types.attrsOf (types.submodule database);
      default = { };
      description = "Databases to create.";
    };
  };

  #### Implementation:
  config = mkIf cfg.enable {
    services.influxdb.enable = true;
    services.influxdb.extraConfig.http.auth-enabled = cfg.auth.enable;

    systemd.services.influxdb-account-manager = {
      description = "InfluxDB accounts and databases";
      wantedBy = [ "multi-user.target" ];
      after = [ "influxdb.service" ] ++ keyservices;
      wants = keyservices;
      path = [ config.services.influxdb.package ];
      script =
        # Configure authentication:
        (optionalString cfg.auth.enable ''
          export INFLUX_USERNAME="${cfg.superuser.name}"
          export INFLUX_PASSWORD=$(head -n 1 "${cfg.superuser.passwordFile}")
        '') +
        # Create superuser:
        (optionalString cfg.auth.enable
          (createuser cfg.superuser.name cfg.superuser.passwordFile true)) +
        # Create all other users:
        (concatMapStringsSep "\n"
          (a: createuser a.name a.passwordFile a.isAdmin) (attrValues cfg.accounts)) +
        # Create databases and grants:
        (concatMapStringsSep "\n" createdb (attrValues cfg.databases));
    };
  };
}
