{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.phoebe.helpers;
  plib = pkgs.phoebe.lib;

  # Generate a systemd.services attrset where the given services wait
  # for NixOps key services.
  waitForKeys = keys: {
    systemd.services = (mapAttrs
      (_: path: optionalAttrs (plib.keys.isKeyFile path) {
        after = plib.keys.keyService path;
        wants = plib.keys.keyService path;
      }) keys);
  };
in
{
  options.phoebe.helpers = {
    waitForKeys = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = ''
        Attribute set of service names and the name of a key file they
        should wait for.
      '';
      example = {
        "wireguard-wg0" = "/run/keys/wireguard";
      };
    };
  };

  config = mkMerge [
    (waitForKeys cfg.waitForKeys)
  ];
}
