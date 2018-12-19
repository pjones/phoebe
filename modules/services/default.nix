{ config, lib, pkgs, ...}:

{
  imports = [
    ./databases
    ./web
  ];
}
