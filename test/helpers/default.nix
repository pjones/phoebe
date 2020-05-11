{ pkgs
}:


pkgs.nixosTest {
  name = "phoebe-helpers";

  nodes = {
    machine = {...}: {
      imports = [ ../../modules ];

      config = {
        systemd.services.foo-key = {
          description = "make the foo key available";
          script = ''
            echo OKAY > /run/keys/foo
            while :; do sleep 60; done;
          '';
        };
        systemd.services.bar = {
          description = "wait for key files";
          script = ''
            echo OKAY > /tmp/bar
            while :; do sleep 60; done;
          '';
        };
        phoebe.helpers.waitForKeys = {
          bar = "/run/keys/foo";
        };
      };
    };
  };

  testScript = ''
    start_all()
    machine.systemctl("start bar.service")
    machine.wait_for_unit("bar.service")
    if not "OKAY" in machine.succeed("cat /tmp/bar"):
        raise Exception("bar service failed")
    if not "OKAY" in machine.succeed("cat /run/keys/foo"):
        raise Exception("bar did not start foo")
  '';
}
