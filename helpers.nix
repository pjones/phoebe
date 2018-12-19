{ pkgs }:

let
  callPackage = pkgs.lib.callPackageWith self;

  self = {
    inherit pkgs;

    rails = callPackage ./modules/services/web/rails/helpers.nix { };
  };
in
{
  inherit (self.rails) mkRailsDerivation;
}
