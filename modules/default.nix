{ config, lib, pkgs, ...}:

{
  imports = [
    ./backup
    ./helpers
    ./security
    ./services
  ];

  nixpkgs.overlays = [
    (self: super: {
      phoebe = import ../default.nix { pkgs = super; };
    })
  ];
}
