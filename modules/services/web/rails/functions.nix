{ config }:

rec {

  ##############################################################################
  # The default base directory for Rails applications:
  base = "/var/lib/rails";

  ##############################################################################
  # Where a Rails application lives:
  home = name: "${base}/${name}";

  ##############################################################################
  # Path to where the app is actually installed:
  appLink = app: "${app.home}/package";

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

}
