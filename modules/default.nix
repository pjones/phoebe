{ config, lib, pkgs, ...}:

{
  imports = [
    ./backup
    ./security
    ./services
  ];

  nixpkgs.overlays = [
    (self: super: {
      phoebe = import ../default.nix { pkgs = super; };
    })
  ];
}
