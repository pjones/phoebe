{ config, lib, pkgs, ...}:

{
  imports = [
    ./builder
    ./databases
    ./monitoring
    ./web
  ];
}
