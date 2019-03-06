{ pkgs ? import <nixpkgs> {}
}:

with pkgs.lib;

let
  callPackage = f:
    let json = removeAttrs (importJSON f) ["date"];
    in callPackageWith attrs "${pkgs.fetchgit json}/default.nix";

  attrs = {
    inherit pkgs;

    # Useful backup scripts.
    backup-scripts = callPackage ./backup-scripts.json { };
  };

in attrs
