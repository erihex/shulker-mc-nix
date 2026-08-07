{ lib, pkgs }:

let
  /*
    Build an immutable directory tree from:

      1. an optional base directory;
      2. zero or more overlay directories;
      3. explicitly generated files.

    Typical result:

      ATM10/mods + minecraft/mods -> $out
      ATM10/tacz + minecraft/tacz -> $out

    The contents of overlay directories are copied recursively as complete
    trees. Individual files inside them are intentionally NOT enumerated by
    Nix code.
  */
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
          if [ -d ${lib.escapeShellArg (toString base)} ]; then
            cp -a \
              ${lib.escapeShellArg "${toString base}/."} \
              "$out/"
          fi
        ''
      }

      ${lib.concatMapStringsSep "\n" (
        overlay:
        ''
          if [ -d ${lib.escapeShellArg (toString overlay)} ]; then
            cp -a \
              ${lib.escapeShellArg "${toString overlay}/."} \
              "$out/"
          fi
        ''
      ) overlays}

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          destination: source:
          ''
            install -Dm644 \
              ${lib.escapeShellArg (toString source)} \
              "$out/${destination}"
          ''
        ) extraFiles
      )}
    '';
in
{
  inherit mkTree;
}