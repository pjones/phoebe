# Configure PostgreSQL:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.services.postgresql;
  plib = config.phoebe.lib;
  superuser = config.services.postgresql.superUser;
  create-user = import ./create-user.nix { inherit config lib pkgs; };
  afterservices = concatMap (a: plib.keyService a.passwordFile) (attrValues cfg.accounts);

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

          If the file looks like it's a NixOps key then the account
          creation script will automatically wait for the appropriate
          key service to start.
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

      superuser = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Allow this user to be a superuser.

          WARNING: You probably don't want to enable this.  However,
          you may have no choice in some situations.  For
          example, when running tests in a Ruby on Rails application
          the test user needs superuser privileges in order to disable
          referential integrity (yuck).
        '';
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
        -e "${concatStringsSep " " account.extensions}" \
        -S "${toString account.superuser}"
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
