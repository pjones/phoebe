{ config, lib, pkgs, ...}:

with lib;

let
  libFiles = [
    ../lib/keys.nix
  ];

  loadLib = path: import path { inherit lib; };
  libs = foldr (a: b: recursiveUpdate (loadLib a) b) {} libFiles;

in
{
  imports = [
    ./security
    ./services
  ];

  options.phoebe.lib = mkOption {
    type = types.attrs;
    default = libs;
    internal = true;
    readOnly = true;
  };
}
