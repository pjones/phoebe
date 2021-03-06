{ config, lib, pkgs, ...}:

with lib;

let
  libFiles = [
    ../lib/keys.nix
    ../lib/shell.nix
  ];

  loadLib = path: import path { inherit lib pkgs; };
  libs = foldr (a: b: recursiveUpdate (loadLib a) b) {} libFiles;

in
{
  imports = [
    ./backup
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
