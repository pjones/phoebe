# Configure monitoring and reporting services.
{ config, lib, pkgs, ...}:

# Bring in library functions:
with lib;

let
  cfg = config.phoebe.services.monitoring.client;

in
{
  #### Interface
  options.phoebe.services.monitoring.client = {
    enable = mkEnableOption "Export Metrics for Prometheus.";
  };

  #### Implementation
  config = mkIf cfg.enable {
    # Enable systemd accounting:
    systemd.enableCgroupAccounting = true;

    # Prometheus node exporter:
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [
        "systemd"
        "logind"
      ];
    };
  };
}
