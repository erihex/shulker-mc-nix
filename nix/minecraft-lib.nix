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

      ${
        lib.optionalString (base != null) ''
          if [ -d ${base} ]; then
            cp -a ${base}/. "$out/"
          fi
        ''
      }

      ${lib.concatMapStringsSep "\n" (overlay: ''
        if [ -d ${overlay} ]; then
          cp -a ${overlay}/. "$out/"
        fi
      '') overlays}

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