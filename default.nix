{ pkgs ? import <nixpkgs> { }
, ...
}:

pkgs.stdenvNoCC.mkDerivation rec {
  name = "phoebe-${version}";
  version = "0.2";
  src = ./.;

  phases =
   [ "unpackPhase"
     "installPhase"
     "fixupPhase"
   ];

  installPhase = ''
    mkdir -p $out
    cp -rp bin modules lib pkgs scripts $out/
    chmod 0555 $out/bin/*
  '';

  passthru = {
    lib = {
      keys = import ./lib/keys.nix { inherit (pkgs) lib; };
      shell = import ./lib/shell.nix { inherit (pkgs) pkgs lib; };
    };
  };
}
