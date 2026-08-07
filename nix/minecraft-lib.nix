{ lib, pkgs }:

let
  mkTree =
    {
      name,
      base ? null,
      overlays ? [ ],
      extraFiles ? { },
    }:

    pkgs.runCommand name { } ''
      set -euo pipefail

      mkdir -p "$out"

      # Base tree, usually from the extracted ATM10 server pack.
      ${
        lib.optionalString (base != null) ''
          if [ -d ${base} ]; then
            cp -a ${base}/. "$out/"

            # Files copied from another Nix store path are normally read-only.
            # Make the build output writable so subsequent overlays can replace
            # files with the same names.
            chmod -R u+w "$out"
          fi
        ''
      }

      # Overlay repository-controlled trees.
      #
      # Later overlays win over earlier contents.
      ${lib.concatMapStringsSep "\n" (overlay: ''
        if [ -d ${overlay} ]; then
          cp -a ${overlay}/. "$out/"
          chmod -R u+w "$out"
        fi
      '') overlays}

      # Generated/explicit files are applied last and therefore have the
      # highest precedence.
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          destination: source:
          ''
            install -Dm644 \
              ${source} \
              "$out/${destination}"
          ''
        ) extraFiles
      )}
    '';
in
{
  inherit mkTree;
}