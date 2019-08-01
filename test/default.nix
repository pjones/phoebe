{ pkgs ? import <nixpkgs> {}
}:

with pkgs;

{
  rails = (callPackage ./services/web/rails/test.nix {}).test;
}
