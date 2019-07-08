Phoebe is a set of [NixOS][] modules that provide additional
functionality on top of the existing modules in [Nixpkgs][].  The name
of this package was taken from the name of [Saturn's moon][phoebe].

Module List
-----------

  * `phoebe.security`:

     Automatically enable various security related settings for NixOS.

  * `phoebe.services.nginx`:

     Extra configuration for nginx (if it's enabled elsewhere).  For
     example, automatically use syslog so no log files need to be
     rotated.  See the `phoebe.services.nginx.syslog` option for more
     details.

  * `phoebe.services.postgresql`:

    Start and manage PostgreSQL, including automatic user and database
    creation.

  * `phoebe.services.influxdb`:

     Start and manage InfluxDB, including users and databases.

  * `phoebe.services.rails`:

    Configure and manage Ruby on Rails applications.  Includes a
    helper function to help package Rails applications so they can be
    used by this service.

  * `phoebe.services.web.tunnels`:

     HTTPS to HTTP private tunnels for web developers.

  * `phoebe.backup.postgresql`:

     Simple backups for PostgreSQL via `pg_dump`.

  * `phoebe.services.networking.wireguard`:

     Simple way to configure a whole network of WireGuard machines.


[nixos]: https://nixos.org/
[nixpkgs]: https://nixos.org/nixpkgs/
[phoebe]: https://en.wikipedia.org/wiki/Phoebe_(moon)
