{ config, lib, pkgs, ...}:

{
  imports = [
    ./nginx
    ./rails
  ];
}
