{ config, lib, pkgs, ...}:

pkgs.stdenvNoCC.mkDerivation {
  name = "pg-create-user";
  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    # Substitution variables:
    export sudo=${pkgs.sudo}/bin/sudo
    export superuser=${config.services.postgresql.superUser}

    mkdir -p $out/bin $out/sql
    cp ${./create-user.sql} $out/sql/create-user.sql
    substituteAll ${./create-user.sh} $out/bin/create-user.sh
    chmod 555 $out/bin/create-user.sh
  '';

  meta = with lib; {
    description = "Automatically create PosgreSQL databases and users as needed.";
    homepage = https://git.devalot.com/pjones/phoebe/;
    maintainers = with maintainers; [ pjones ];
    platforms = platforms.all;
  };
}
