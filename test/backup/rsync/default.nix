{ pkgs ? import <nixpkgs> {}
}:

let
  service = "rsync-localhost-tmp-backup.service";

in
pkgs.nixosTest {
  name = "rsync-backup-test";

  nodes = {
    simple = {config, pkgs, ...}: {
      imports = [ ../../../modules ];
      phoebe.security.enable = false;
      services.openssh.enable = true;

      users.users.root.openssh.authorizedKeys.keys = [
        (builtins.readFile ../../data/ssh.id_ed25519.pub)
      ];

      phoebe.backup.rsync = {
        enable = true;
        schedules = [
          { host = "localhost";
            directory = "/tmp/backup";
            user = "root";
            key = "/tmp/key";
            services = [ "sshd.service" ];
          }
        ];
      };
    };
  };

  testScript = ''
    $simple->start;
    $simple->copyFileFromHost("${../../data/ssh.id_ed25519}", "/tmp/key");
    $simple->succeed("chmod 0600 /tmp/key");
    $simple->succeed("chown backup:backup /tmp/key");
    $simple->succeed("mkdir /tmp/backup");
    $simple->succeed("echo OKAY > /tmp/backup/file");
    $simple->waitForUnit("sshd.service");
    $simple->systemctl("start ${service}");
    $simple->waitForUnit("${service}");
    $simple->waitUntilFails("systemctl status ${service} | grep -q 'Active: active'");
    $simple->succeed("cat /var/backup/rsync/localhost/tmp-backup/*/file") =~ /OKAY/ or die;
  '';
}
