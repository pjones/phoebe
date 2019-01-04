# Functions for generating and working with shell scripts:
{ lib, pkgs, ... }:


with lib;

let
  funcs = rec {

    # Generate a shell script that exports the given variables.
    #
    # Type:
    #
    #   string -> attrset -> derivation
    #
    # Arguments:
    #
    #   fileName: The name of the file in the nix store to create.
    #   attrs:    The variables to include in the generated script.
    #
    attrsToShellExports = fileName: attrs:
      let export = name: value: "export ${name}=${escapeShellArg value}";
          lines  = mapAttrsToList export attrs;
      in pkgs.writeText fileName (concatStringsSep "\n" lines);
  };

in funcs
