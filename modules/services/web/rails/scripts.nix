{ lib, pkgs, ...}:

pkgs.stdenvNoCC.mkDerivation {
  name = "rails-scripts";
  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    substituteAll ${./db-migrate.sh} $out/bin/db-migrate.sh
    find $out/bin -type f -exec chmod 555 '{}' ';'
  '';

  meta = with lib; {
    description = "Scripts for working with Ruby on Rails applications.";
    homepage = https://git.devalot.com/pjones/phoebe/;
    maintainers = with maintainers; [ pjones ];
    platforms = platforms.all;
  };
}
