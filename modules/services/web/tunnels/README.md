Secure Public Tunnels to Private Services
=========================================

Software developers sometimes need to provide public access to a
private resource such as web service running behind NAT or in a
virtual machine.  In such situations we need a public web server with
a valid SSL/TLS certificate that forwards connections to a private
server that is using plain HTTP.

There are existing open and commercial solutions to this problem.  For
example, [ngrok](https://ngrok.com/) is a well-known commercial
service.  However, a similar setup is fairly easy to create using
OpenSSH.

How This Works
--------------

  * A public domain name points to a server you control running NixOS.

  * This service starts nginx and creates the necessary SSL/TLS
    certificate.

  * Connections on port 443 for the public domain are forwarded to a
    configured port on the local system.  For now let's assume we are
    going to use port 9000.

  * The software developer creates an SSH tunnel to the NixOS machine
    running this service, forwarding remote port 9000 (or whatever
    port you want) to a local host/port pair.


Example Configuration
---------------------

The following NixOS configuration enables nginx for the `example.com`
domain, requesting a SSL/TLS certificate for `webapp.example.com`.

Requests to `webapp.example.com` on port 443 are forwarded to port 9000.

```nix
phoebe.services.web.tunnels = {
  enable = true;
  hostName = "example.com";

  accounts = [{
    authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1g7KoenMd6JIWnIuOQOYAaPNk6rF+6vwXBqNic2Juk elphaba";
    tunnels = [{subdomain = "webapp"; serverPort = 9000;}];
  }];
};
```

A software developer would take advantage of this configuration by
establishing an SSH tunnel to `example.com` on port 9000.  In this
example, let's assume the developer wants to have `webapp.example.com`
requests sent to a local service running on port 3000:

```sh
ssh -R 9000:localhost:3000 -N tunnel@webapp.example.com
```
