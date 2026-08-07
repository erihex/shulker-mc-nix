{ lib, pkgs }:

let
  # Recursively turn a source directory into:
  #
  # {
  #   "relative/path/file.ext" = /nix/store/...-source/relative/path/file.ext;
  # }
  #
  # Directory entries are discovered at Nix evaluation time, so adding a new
  # file below a repository-controlled directory requires no Nix code changes.
  recursiveFiles =
    root:
    let
      walk =
        prefix: dir:
        lib.concatMapAttrs (
          name: type:
          let
            path = dir + "/${name}";
            relative = if prefix == "" then name else "${prefix}/${name}";
          in
          if type == "directory" then
            walk relative path
          else if type == "regular" || type == "symlink" then
            { ${relative} = path; }
          else
            { }
        ) (builtins.readDir dir);
    in
    if builtins.pathExists root then walk "" root else { };

  # Generate shell commands that copy an attrset produced by recursiveFiles.
  # install -D creates all parent directories automatically.
  installFiles =
    destinationRoot: files:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (relative: source: ''
        install -Dm644 \
          ${lib.escapeShellArg (toString source)} \
          "${destinationRoot}/${relative}"
      '') files
    );

  # Build an immutable server directory tree from any combination of:
  #   * a base tree (usually from the ATM server pack);
  #   * repository-controlled overlay directories;
  #   * generated individual files.
  #
  # This is intentionally generic: mods, config, tacz, datapacks, etc. all use
  # the same implementation.
  mkTree =
    {
      name,
      base ? null,
      overlays ? [ ],
      extraFiles ? { },
    }:
    pkgs.runCommand name { } ''
      mkdir -p "$out"

      ${
        if base == null then
          ""
        else
          ''
            if [ -d ${base} ]; then
              cp -a ${base}/. "$out/"
            fi
          ''
      }

      ${lib.concatMapStringsSep "\n" (
        overlay:
        let
          files = recursiveFiles overlay;
        in
        installFiles "$out" files
      ) overlays}

      ${installFiles "$out" extraFiles}
    '';
in
{
  inherit recursiveFiles installFiles mkTree;
}
