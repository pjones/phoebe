{ config, lib, pkgs, ...}:

{
  imports = [
    ./databases
    ./monitoring
    ./web
  ];
}
