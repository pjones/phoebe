{ config, lib, pkgs, ...}:

{
  imports = [
    ./builder
    ./databases
    ./web
  ];
}
