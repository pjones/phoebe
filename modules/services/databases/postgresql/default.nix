# Configure PostgreSQL:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.services.postgresql;
  superuser = config.services.postgresql.superUser;
  create-user = import ./create-user.nix { inherit config lib pkgs; };
  afterservices = concatMap (a: a.afterServices) (attrValues cfg.accounts);

  # Per-account options:
  account = { name, ... }: {

    #### Interface:
    options = {
      user = mkOption {
        type = types.str;
        default = null;
        example = "jdoe";
        description = "The name of the account (username).";
      };

      passwordFile = mkOption {
        type = types.path;
        default = null;
        example = "/run/keys/pgpass.txt";
        description = ''
          A file containing the password of this database user.
          You'll want to use something like NixOps to get the password
          file onto the target machine.
        '';
      };

      afterServices = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "dbpassword.service" ];
        description = ''
          A list of services that need to run before this user account
          can be created.  This is really useful if you are using
          NixOps to deploy the password file and want to wait for the
          key to appear in /run/keys.
        '';
      };

      database = mkOption {
        type = types.str;
        default = null;
        example = "jdoe";
        description = ''
          The name of the database this user can access.  Defaults to
          the account name.
        '';
      };

      extensions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "pg_trgm" ];
        description = "A list of extension modules to enable for the database.";
      };

      netmask = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "127.0.0.1/32";
        description = ''
          IP netmask of remote machines allowed to connect.  Leaving
          this at it's default value means this account can only
          connect through Unix domain sockets.
        '';
      };
    };

    #### Implementation:
    config = {
      user = mkDefault name;
      database = mkDefault name;
    };
  };

  # Create HBA authentication entries:
  accountToHBA = account:
    ''
      local ${account.database} ${account.user}              md5
      host  ${account.database} ${account.user} 127.0.0.1/32 md5
      host  ${account.database} ${account.user} ::1/28       md5
    '' + optionalString (account.netmask != null) ''
      host  ${account.database} ${account.user} ${account.netmask} md5
    '';

  # Commands to run to create accounts/databases:
  createScript = account:
    ''
      ${create-user}/bin/create-user.sh \
        -u "${account.user}" \
        -d "${account.database}" \
        -p "${account.passwordFile}" \
        -e "${concatStringsSep " " account.extensions}"
    '';

in
{
  #### Interface
  options.phoebe.services.postgresql = {
    enable = mkEnableOption "PostgreSQL";

    accounts = mkOption {
      type = types.attrsOf (types.submodule account);
      default = { };
      description = "Additional user accounts";
    };
  };

  #### Implementation
  config = mkIf cfg.enable {

    # Set up PosgreSQL:
    services.postgresql = {
      enable = true;
      enableTCPIP = true;
      package = pkgs.postgresql;

      # The superuser can access all databases locally, remote access
      # for some users.
      authentication = mkForce (
        "local all ${superuser} peer\n" +
        "host  all ${superuser} 127.0.0.1/32 ident\n" +
        "host  all ${superuser} ::1/128      ident\n" +
        concatMapStringsSep "\n" accountToHBA (attrValues cfg.accounts));
    };

    # Create missing accounts:
    systemd.services.pg-accounts = mkIf (length (attrValues cfg.accounts) > 0) {
      description = "PostgreSQL Account Manager";
      path = [ pkgs.gawk config.services.postgresql.package ];
      script = (concatMapStringsSep "\n" createScript (attrValues cfg.accounts));
      wantedBy = [ "postgresql.service" ];
      after = [ "postgresql.service" ] ++ afterservices;
      wants = afterservices;
    };
  };
}
