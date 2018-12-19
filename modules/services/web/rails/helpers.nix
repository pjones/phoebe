# Helper package Ruby on Rails applications that work with the rails
# service in this directory.
{ pkgs, ... }:

let
  functions = import ./functions.nix;

  mkRailsDerivation =
    { name
    , env # The output of bundlerEnv
    , extraPackages ? [ ]
    , buildPhase ? ""
    , installPhase ? ""
    , buildInputs ? [ ]
    , propagatedBuildInputs ? [ ]
    , ...
    }@args:
      pkgs.stdenv.mkDerivation (args // {
        buildInputs = [ env env.wrappedRuby ] ++ buildInputs;
        propagatedBuildInputs = extraPackages ++ propagatedBuildInputs;
        passthru = { rubyEnv = env; ruby = env.wrappedRuby; };

        buildPhase = ''
          ${buildPhase}

          # Build all the assets into the package:
          rake assets:precompile

          # Move some files out of the way since they will be created
          # in production:
          rm config/database.yml
          mv config config.dist
          mv db/schema.rb db/schema.rb.dist
        '';

        installPhase = ''
          mkdir -p "$out/share"
          ${installPhase}

          cp -r . "$out/share/${name}"
          rm -rf  "$out/share/${name}/log"
          rm -rf  "$out/share/${name}/tmp"

          # Install some links to where the app lives in production:
          for f in log config tmp db/schema.rb; do
            ln -sf "${functions.home name}/$f" "$out/share/${name}/$f"
          done
        '';
      });
in
{ inherit mkRailsDerivation;
}
