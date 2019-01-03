# Functions for working with NixOps keys.
{ lib }:

with lib;

let
  # Where NixOps stores keys:
  keyDirectory = "/run/keys/";

  # Generate a service name:
  mkServiceName = path:
    replaceStrings ["/"] ["-"]
      (removePrefix keyDirectory path + "-key.service");

  funcs = rec {

    /* Test to see if a file path is a NixOps managed key.

       Example:
         isKeyFile "/run/keys/foo"
         => true
         isKeyFile "/etc/passwd"
         => false
    */
    isKeyFile = path:
      if path == null
        then false
        else hasPrefix keyDirectory path;

    /* Returns an array containing a systemd service name that can be
       used to add a 'wants' or 'after' entry for a NixOps key.

       Example:
         keyService "/run/keys/foo"
         => ["foo.service"]
         keyService "/etc/passwd"
         => []
    */
    keyService = path: optional (isKeyFile path) (mkServiceName path);

  };

in funcs
