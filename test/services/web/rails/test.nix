{ pkgs ? import <nixpkgs> {}
}:

pkgs.nixosTest {
  name = "rails-test";

  nodes = {
    simple = {config, pkgs, ...}: {
      imports = [ ../../../../modules ];
      phoebe.security.enable = false;
      phoebe.services.rails.apps.app = {
        package = import ./app/default.nix { inherit pkgs; };
        domain = "foo.example.com";
        port = 3000;
        database.name = "app";
        database.user = "app";
        database.passwordFile = "/dev/null";
      };
    };
  };


  testScript = ''
    start_all()
    simple.wait_for_unit("rails-app-main.service")
    simple.succeed("railsdo app rake -T")
    simple.succeed("test -L /var/lib/rails/app/package")
  '';
}
