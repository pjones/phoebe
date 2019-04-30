# Configure PostgreSQL:
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.services.postgresql;
  plib = config.phoebe.lib;
  superuser = config.services.postgresql.superUser;
  scripts = import ./scripts.nix { inherit config lib pkgs; };
  afterservices = concatMap (a: plib.keyService a.passwordFile) (attrValues cfg.accounts);

  # Per-database options:
  database = { name, ...}: {

    #### Interface:
    options = {
      name = mkOption {
        type = types.str;
        example = "sales";
        description = "The name of the database.";
      };

      owner = mkOption {
        type = types.str;
        default = superuser;
        example = "jdoe";
        description = "Name of the account that owns the database.";
      };

      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "alice" ];
        description = "List of user names who have full access to the database.";
      };

      readers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "bob" ];
        description = "List of user names who have read-only access to the database";
      };

      extensions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "pg_trgm" ];
        description = "A list of extension modules to enable for the database.";
      };
    };

    #### Implementation:
    config = {
      name = mkDefault name;
    };
  };

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

      allowIdent = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Whether or not this account can use ident authentication
          when connecting locally.
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
    };
  };

  # Create HBA authentication entries:
  accountToHBA = account:
    let local = if account.allowIdent then "ident" else "md5";
        template = database: (''
          local ${database} ${account.user}              ${local}
          host  ${database} ${account.user} 127.0.0.1/32 md5
          host  ${database} ${account.user} ::1/28       md5
        '' + optionalString (account.netmask != null) ''
          host  ${database} ${account.user} ${account.netmask} md5
        '');
        databases = map (d: d.name)
          (filter (d: d.owner == account.user   ||
                      elem account.user d.users ||
                      elem account.user d.readers)
            (attrValues cfg.databases));
    in if account.superuser
          then template "all"
          else concatMapStringsSep "\n" template databases;

  # Commands to run to create accounts:
  createUser = account:
    let options = [
      ''-u "${account.user}"''
      ''-p "${account.passwordFile}"''
    ] ++ optional account.superuser "-S";
    in ''
      ${scripts}/bin/create-user.sh ${concatStringsSep " " options}
    '';

  # Commands to run to create databases:
  createDB = database:
    ''
      ${scripts}/bin/create-db.sh \
        -d "${database.name}" \
        -o "${database.owner}" \
        -e "${concatStringsSep " " database.extensions}"
    '';

  # Commands to run to create full grants:
  createGrant = database: account:
    ''
      ${scripts}/bin/create-grant.sh \
        -a rw \
        -u "${account.user}" \
        -d "${database.name}"
    '';

  # Commands to run to create read-only grants:
  createReadGrant = database: account:
    ''
      ${scripts}/bin/create-grant.sh \
        -a r \
        -u "${account.user}" \
        -d "${database.name}"
    '';

  # Generate a SQL statement that allows a user to login:
  allowLogin = accounts: concatMapStringsSep "\n" (account: ''
    echo "ALTER ROLE ${account.user} LOGIN;"
  '') accounts;

  # Lock out accounts that are not configured:
  lockAccounts = accounts: ''
    sql_file=$(mktemp)

    # Lock all accounts:
    ${scripts}/bin/nologin.sh > "$sql_file"

    # Unlock configured accounts:
    (
      ${allowLogin accounts}
    ) >> "$sql_file"

    chown ${superuser} "$sql_file"

    ${pkgs.sudo}/bin/sudo -u ${superuser} -H \
      psql --dbname="postgres" --file="$sql_file" --single-transaction

    rm "$sql_file"
  '';

  # Master grant creation function:
  createGrants = database:
    let find = names: map (name: cfg.accounts."${name}")
                        (filter (name: cfg.accounts ? "${name}")
                          names);
        ro = find database.readers;
        rw = find (database.users ++ [database.owner]);
        owner = find [database.owner];
    in (concatMapStringsSep "\n" (createReadGrant database) ro) +
       (concatMapStringsSep "\n" (createGrant database) rw);
in
{
  #### Interface
  options.phoebe.services.postgresql = {
    enable = mkEnableOption "PostgreSQL";

    accounts = mkOption {
      type = types.attrsOf (types.submodule account);
      default = { };
      description = "Additional user accounts.";
    };

    databases = mkOption {
      type = types.attrsOf (types.submodule database);
      default = { };
      description = "Additional databases to create.";
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
    systemd.services.postgres-account-manager = {
      description = "PostgreSQL Account Manager";
      path = [ pkgs.gawk config.services.postgresql.package ];
      wantedBy = [ "postgresql.service" ];
      after = [ "postgresql.service" ] ++ afterservices;
      wants = afterservices;

      script = ''
        set -e
      '' + (concatMapStringsSep "\n" createUser (attrValues cfg.accounts))
         + (lockAccounts (attrValues cfg.accounts))
         + (concatMapStringsSep "\n" createDB (attrValues cfg.databases))
         + (concatMapStringsSep "\n" createGrants (attrValues cfg.databases));
    };
  };
}
