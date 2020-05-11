{ sources ? import ../nix/sources.nix,
  pkgs ? import sources.nixpkgs {}
}:

with pkgs;

{
  rails = (callPackage ./services/web/rails/test.nix {}).test;
  backup-rsync = (callPackage ./backup/rsync {}).test;
  backup-script = (callPackage ./backup/script {}).test;
  helpers = (callPackage ./helpers {}).test;
}
