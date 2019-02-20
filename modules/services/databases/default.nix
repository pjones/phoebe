{ config, lib, pkgs, ...}:

{
  imports = [
    ./influxdb
    ./postgresql
  ];
}
