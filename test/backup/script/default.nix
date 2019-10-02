{ pkgs ? import <nixpkgs> {}
}:

let
  service = "backup-test.service";

in
pkgs.nixosTest {
  name = "backup-script-test";

  nodes = {
    simple = {config, pkgs, ...}: {
      imports = [ ../../../modules ];
      phoebe.security.enable = false;

      phoebe.backup.scripts.test = {
        user  = "root";
        script = "cp /etc/issue /tmp/issue";
      };
    };
  };

  testScript = ''
    $simple->start;
    $simple->systemctl("start ${service}");
    $simple->waitUntilFails("systemctl status ${service} | grep -q 'Active: active'");
    $simple->succeed("cat /tmp/issue") =~ /NixOS/ or die;
  '';
}
