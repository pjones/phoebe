{ stdenvNoCC
, netdata
}:

stdenvNoCC.mkDerivation {
  name = "netdata-extra-scripts";
  phases = [ "installPhase" "fixupPhase" ];

  installPhase = ''
    mkdir -p $out/plugins.d $out/charts.d
    install -m 0555 ${netdata}/libexec/netdata/plugins.d/charts.d.plugin $out/plugins.d/phoebe.charts.d.plugin
    install -m 0555 ${./charts.d/services.chart.sh} $out/charts.d/services.chart.sh

    # Force our copy of charts.d.plugin to use the correct charts.d directory:
    sed -i "s|^chartsd=.*|chartsd=$out/charts.d|" $out/plugins.d/phoebe.charts.d.plugin
  '';
}
