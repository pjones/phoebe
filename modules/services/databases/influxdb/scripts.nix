{ config, lib, pkgs, ...}:

pkgs.stdenvNoCC.mkDerivation {
  name = "influx-account-manager";
  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    # Substitution variables:
    mkdir -p $out/bin
    install -m 0555 ${./createdb.sh}    $out/bin/createdb.sh
    install -m 0555 ${./createuser.sh}  $out/bin/createuser.sh
    install -m 0555 ${./creategrant.sh} $out/bin/creategrant.sh
  '';

  meta = with lib; {
    description = "Automatically create InfluxDB databases and users as needed.";
    homepage = https://git.devalot.com/pjones/phoebe/;
    maintainers = with maintainers; [ pjones ];
    platforms = platforms.all;
  };
}
