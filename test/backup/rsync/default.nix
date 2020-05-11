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
        user = "root";
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
    start_all()
    simple.copy_from_host(
        "${../../data/ssh.id_ed25519}", "/tmp/key"
    )
    simple.succeed("chmod 0600 /tmp/key")
    simple.succeed("chown backup:backup /tmp/key")
    simple.succeed("mkdir /tmp/backup")
    simple.succeed("echo OKAY > /tmp/backup/file")
    simple.wait_for_unit("sshd.service")
    simple.systemctl("start ${service}")
    simple.wait_for_unit("${service}")
    simple.wait_until_fails(
        "systemctl status ${service} | grep -q 'Active: active'"
    )
    if not "OKAY" in simple.succeed("cat /var/backup/rsync/localhost/tmp-backup/*/file"):
        raise Exception("rsync failed")
  '';
}
