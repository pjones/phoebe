# The common situation where you have a distributed network of
# machines that want to talk to one another over WireGuard.
{ config, lib, pkgs, ...}: with lib;

let
  # Shorthand:
  cfg = config.phoebe.services.networking.wireguard;

  # Private library functions:
  plib = pkgs.phoebe.lib;

  ##############################################################################
  # Per-machine options:
  machineOpts = { name, ... }: {
    #### Interface:
    options = {
      name = mkOption {
        type = types.str;
        example = "myhost";
        description = "Host name without domain.";
      };

      publicKey = mkOption {
        type = types.str;
        example = "SOKmBk+ZcKIXql49vuWc+uaVYxsvb8EaJZDOiQdUSFU=";
        description = "WireGuard public key for this machine.";
      };

      ip = mkOption {
        type = types.str;
        example = "192.168.1.2/32";
        description = "WireGuard IP address with mask.";
      };

      routes = mkOption {
        type = types.listOf types.str;
        example = [ "10.10.0.0/24" ];
        default = [ ];
        description = ''List of IP addresses with masks.  Traffic
          destined for an IP address in this list will be routed
          through this machine.'';
      };

      endpoint = mkOption {
        type = types.nullOr types.str;
        example = "myhost.example.com:51820";
        default = null;
        description = ''Optional FQDN and port number to reach this
          machine from outside WireGuard.  Only needed if you want to
          make outbound connections to this machine.  Not necessary to
          allow inbound connetions from this machine.'';
      };

      keepAlive = mkOption {
        type = types.nullOr types.ints.positive;
        example = 25;
        default = null;
        description = ''If set, send a keep-alive packet every N
          seconds.  Usually not necessary.'';
      };

      current = mkOption {
        type = types.bool;
        example = true;
        description = ''Is this machine the one currently being
          configured?  If so, all other machines are configured as
          peers.  By default, if this machine's name matches the
          current host name this option will be set to true.'';
      };
    };

    #### Implementation:
    config = {
      name = mkDefault name;
      current = mkDefault (name == config.networking.hostName);
    };
  };

  ##############################################################################
  # Per-network options:
  networkOpts = { name, ... }: {
    #### Interface:
    options = {
      name = mkOption {
        type = types.str;
        example = "wg0";
        description = "Network (and interface) name.";
      };

      privateKey = mkOption {
        type = with types; either path str;
        example = "/run/keys/wireguard";
        description = ''WireGuard private key.  Can be given as a path
            or a string but a path is preferred for security to keep
            the private key out of the nix store.  When using a path
            that looks like a NixOps key, the WireGuard service will
            automatically wait for the key to appear before starting.
            '';
      };

      port = mkOption {
        type = types.nullOr types.ints.positive;
        default = 51820;
        example = null;
        description = ''Port number to listen on, or
          <literal>null</literal> to disable listening.'';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "Open the firewall for the UDP WireGuard port.";
      };

      machines = mkOption {
        type = types.attrsOf (types.submodule machineOpts);
        example = {
          myhost = {
            publicKey = "SOKmBk+ZcKIXql49vuWc+uaVYxsvb8EaJZDOiQdUSFU=";
            ip = "10.0.1.2/32";
          };
        };
        default = { };
        description = ''The machines on this network, only one of which
          may be the current machine'';
      };
    };

    #### Implementation:
    config = {
      name = mkDefault name;
    };
  };

  ############################################################################
  # Configure a WireGuard peer:
  mkPeer = machine: {
    publicKey = machine.publicKey;
    allowedIPs = [ machine.ip ] ++ machine.routes;
    persistentKeepalive = mkIf (machine.keepAlive != null) machine.keepAlive;
    endpoint = mkIf (machine.endpoint != null) machine.endpoint;
  };

  ############################################################################
  # Configure a network:
  mkNetwork = nw: {
    # FIXME: Assert there's exactly one current machine!
    "${nw.name}" = {
      ips = map (m: m.ip) (filter (m: m.current) (attrValues nw.machines));
      listenPort = mkIf (nw.port != null) nw.port;
      peers = map (m: mkPeer m) (filter (m: !m.current) (attrValues nw.machines));

      privateKeyFile =
        if builtins.substring 0 1 (toString nw.privateKey) == "/"
        then nw.privateKey
        else toString (pkgs.writeText "${nw.name}-pk" nw.privateKey);
    };
  };

in
{
  #### Interface:
  options.phoebe.services.networking.wireguard = {
    networks = mkOption {
      type = types.attrsOf (types.submodule networkOpts);
      default = { };
      description = "Networks to configure.";
    };
  };

  #### Implementation:
  config = mkIf (length (attrValues cfg.networks) > 0) {
    # Allow routing through the WireGuard interfaces:
    networking.nat.enable = true;
    networking.nat.internalInterfaces =
      map (n: n.name) (attrValues cfg.networks);

    # Trust WireGuard interfaces:
    networking.firewall.trustedInterfaces =
      map (n: n.name) (attrValues cfg.networks);

    # Optionally open the firewall for WireGuard ports:
    networking.firewall.allowedUDPPorts =
      map (n: n.port) (filter (n: n.openFirewall)
        (attrValues cfg.networks));

    # Configure the WireGuard interfaces:
    networking.wireguard.interfaces =
      foldr (a: b: mkNetwork a // b) { } (attrValues cfg.networks);

    # Extra systemd service configuration:
    phoebe.helpers.waitForKeys = builtins.listToAttrs
      (map (nw: {
        name = "wireguard-${nw.name}";
        value = nw.privateKey;
      }) (attrValues cfg.networks));
  };
}
