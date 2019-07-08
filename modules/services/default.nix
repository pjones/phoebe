{ config, lib, pkgs, ...}:

{
  imports = [
    ./builder
    ./databases
    ./monitoring
    ./networking
    ./web
  ];
}
