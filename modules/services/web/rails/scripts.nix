{ lib, pkgs, ...}:

{
  user = pkgs.stdenvNoCC.mkDerivation {
    name = "rails-user-scripts";
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
  };

  system = pkgs.stdenvNoCC.mkDerivation {
    name = "rails-system-scripts";
    phases = [ "installPhase" "fixupPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      substituteAll ${./railsdo.sh} $out/bin/railsdo
      find $out/bin -type f -exec chmod 555 '{}' ';'
    '';

    meta = with lib; {
      description = "Scripts for working with Ruby on Rails applications.";
      homepage = https://git.devalot.com/pjones/phoebe/;
      maintainers = with maintainers; [ pjones ];
      platforms = platforms.all;
    };
  };
}
