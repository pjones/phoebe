# Configure a machine as a remote builder server.
{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.phoebe.services.builder;

  command = concatStringsSep " " [
    "${pkgs.coreutils}/bin/nice -n${toString cfg.server.niceness}"
    "${config.nix.package.out}/bin/nix-store --serve --write"
  ];

in
{
  #### Interface
  options.phoebe.services.builder = {
    server = {
      enable = mkEnableOption "Whether to allow remote building on this machine.";

      user = mkOption {
        type = types.str;
        default = "nix-remote-bld";
        description = "Builder user account.";
      };

      niceness = mkOption {
        type = types.int;
        default = 10;
        example = 20;
        description = "The amount of niceness to add to the build process.";
      };

      signingKey = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/keys/my-signing-key.sec";
        description = ''
          Optional signing key for locally built/cached paths.  Needed
          if you want to use this host as a substituter.

          Generate the key by running `nix-store --generate-binary-cache-key'
          and then distribute the public key to all clients.
        '';
      };

      clientKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "ssh-ed25519 AAAAB3NzaC1k... alice@example.org" ];
        description = "A list of SSH public keys allowed write access to the nix store.";
      };
    };
  };

  #### Implementation
  config = mkIf cfg.server.enable {
    users.users."${cfg.server.user}" = {
      description = "Nix remote build user";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = cfg.server.clientKeys;
    };

    nix.trustedUsers = [ "${cfg.server.user}" ];

    nix.extraOptions = optionalString (cfg.server.signingKey != null) ''
      secret-key-files = ${cfg.server.signingKey}
    '';

    services.openssh.enable = true;

    services.openssh.extraConfig = ''
      Match User ${cfg.server.user}
        AllowAgentForwarding no
        AllowTcpForwarding no
        PermitTTY no
        PermitTunnel no
        X11Forwarding no
        ForceCommand ${command}
      Match All
    '';
  };
}
