{ pkgs ? import <nixpkgs> { }
}:

let
  phoebe = import ../../../../../helpers.nix { inherit pkgs; };

  puma = pkgs.writeShellScriptBin "puma" ''
    # Loop forever:
    while :; do :; done
  '';

  env = pkgs.bundlerEnv {
    name = "app-env";
    ruby = pkgs.ruby;
    gemfile  = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset   = ./nix/gemset.nix;
  };

in

phoebe.mkRailsDerivation {
  inherit env;
  name = "app";
  src = ./.;
  extraPackages = [ puma ];
}
