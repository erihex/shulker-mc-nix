{ lib, pkgs }:

let
  /*
    Apply ordinary directory overlays.

    Later sources win by relative path. Use this for config/, tacz/, and other
    non-mod trees where filename replacement is the intended behaviour.
  */
  mkOverlayTree =
    {
      name,
      sources ? [ ],
      files ? { },
    }:
    pkgs.runCommand name { } ''
      set -euo pipefail
      mkdir -p "$out"

      ${lib.concatMapStringsSep "\n" (source: ''
        if [ -d ${source} ]; then
          cp -a ${source}/. "$out/"
          chmod -R u+w "$out"
        fi
      '') sources}

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          destination: source: ''
            install -Dm644 ${source} "$out/${destination}"
          ''
        ) files
      )}
    '';

  /*
    Build the final mods/ directory with an explicit policy.

    removeBaseJars:
      Exact filenames removed from ATM before validation. This is intended for
      defects or unwanted files in the upstream server pack.

    replaceBaseModIds:
      modIds which minecraft/mods is explicitly allowed to replace. An extra
      JAR that collides with ATM by modId fails unless every colliding modId is
      listed here.

    Safety checks:
      - removeBaseJars must exist (no stale entries);
      - ATM must have no duplicate modIds after removals;
      - extras must have no duplicate modIds;
      - undeclared ATM/extra modId collisions fail;
      - replaceBaseModIds must correspond to real collisions;
      - replacing a multi-mod ATM JAR may not silently drop another modId;
      - same-filename opaque JAR collisions fail;
      - final output is validated again.
  */
  mkModSet =
    {
      name,
      baseMods,
      extraMods,
      removeBaseJars ? [ ],
      replaceBaseModIds ? [ ],
    }:
    let
      policy = pkgs.writeText "${name}-policy.json" (
        builtins.toJSON {
          inherit removeBaseJars replaceBaseModIds;
        }
      );

      script = pkgs.writeText "${name}-builder.py" ''
        import json
        import os
        import shutil
        import stat
        import sys
        import tomllib
        import zipfile
        from collections import defaultdict
        from pathlib import Path

        METADATA_FILES = (
            "META-INF/neoforge.mods.toml",
            "META-INF/mods.toml",
        )


        class ValidationError(RuntimeError):
            pass


        def jar_files(directory: Path) -> list[Path]:
            if not directory.is_dir():
                return []
            return sorted(
                path
                for path in directory.iterdir()
                if path.is_file() and path.suffix.lower() == ".jar"
            )


        def mod_ids(jar: Path) -> frozenset[str]:
            try:
                with zipfile.ZipFile(jar) as archive:
                    raw = None
                    for metadata_name in METADATA_FILES:
                        try:
                            raw = archive.read(metadata_name)
                            break
                        except KeyError:
                            pass

                    # A top-level library JAR may intentionally not declare a
                    # mod. Such files remain opaque and are still protected
                    # against exact filename collisions.
                    if raw is None:
                        return frozenset()

                metadata = tomllib.loads(raw.decode("utf-8"))
                return frozenset(
                    mod["modId"]
                    for mod in metadata.get("mods", [])
                    if isinstance(mod, dict)
                    and isinstance(mod.get("modId"), str)
                    and mod["modId"]
                )
            except (
                OSError,
                zipfile.BadZipFile,
                UnicodeDecodeError,
                tomllib.TOMLDecodeError,
            ) as exc:
                raise ValidationError(
                    f"Cannot inspect mod metadata in {jar.name}: {exc}"
                ) from exc


        def index(directory: Path):
            by_jar: dict[Path, frozenset[str]] = {}
            by_id: dict[str, list[Path]] = defaultdict(list)

            for jar in jar_files(directory):
                ids = mod_ids(jar)
                by_jar[jar] = ids
                for mod_id in ids:
                    by_id[mod_id].append(jar)

            return by_jar, by_id


        def validate_unique(label: str, by_id):
            duplicates = {
                mod_id: jars
                for mod_id, jars in by_id.items()
                if len(jars) > 1
            }
            if not duplicates:
                return

            lines = [f"{label} contains duplicate modIds:"]
            for mod_id, jars in sorted(duplicates.items()):
                lines.append(f"  {mod_id}:")
                lines.extend(f"    - {jar.name}" for jar in jars)

            raise ValidationError("\n".join(lines))


        def make_writable(root: Path):
            for path in [root, *root.rglob("*")]:
                try:
                    path.chmod(path.stat().st_mode | stat.S_IWUSR)
                except OSError:
                    pass


        def copy_directory_contents(source: Path, destination: Path):
            if not source.is_dir():
                return

            for item in sorted(source.iterdir()):
                target = destination / item.name

                if item.is_dir():
                    if target.exists():
                        if target.is_dir():
                            shutil.rmtree(target)
                        else:
                            target.unlink()
                    shutil.copytree(item, target)
                else:
                    shutil.copy2(item, target)


        def main():
            base = Path(sys.argv[1])
            extra = Path(sys.argv[2])
            out = Path(sys.argv[3])
            policy = json.loads(Path(sys.argv[4]).read_text())

            remove_base_jars = set(policy["removeBaseJars"])
            replace_ids = set(policy["replaceBaseModIds"])

            if not base.is_dir():
                raise ValidationError(f"ATM mods directory does not exist: {base}")

            # Work on a private writable copy of the ATM mod directory.
            shutil.copytree(base, out, dirs_exist_ok=True)
            make_writable(out)

            existing_base_names = {
                path.name
                for path in out.iterdir()
                if path.is_file()
            }

            missing_removals = remove_base_jars - existing_base_names
            if missing_removals:
                raise ValidationError(
                    "removeBaseJars contains filenames not present in the ATM "
                    "server pack:\n"
                    + "\n".join(
                        f"  - {name}"
                        for name in sorted(missing_removals)
                    )
                )

            for filename in sorted(remove_base_jars):
                print(f"Removing ATM JAR: {filename}")
                (out / filename).unlink()

            # Validate the cleaned ATM set, not the unmodified upstream pack.
            base_by_jar, base_by_id = index(out)
            extra_by_jar, extra_by_id = index(extra)

            validate_unique("ATM10 mods after removeBaseJars", base_by_id)
            validate_unique("minecraft/mods", extra_by_id)

            collisions = set(base_by_id) & set(extra_by_id)

            undeclared = collisions - replace_ids
            if undeclared:
                lines = [
                    "Extra mods collide with mods already shipped by ATM10.",
                    "Remove the redundant extra JAR, or explicitly allow the "
                    "replacement in replaceBaseModIds:",
                ]

                for mod_id in sorted(undeclared):
                    lines.append(f"  {mod_id}:")
                    lines.append(
                        f"    ATM10: {base_by_id[mod_id][0].name}"
                    )
                    lines.append(
                        f"    extra: {extra_by_id[mod_id][0].name}"
                    )

                raise ValidationError("\n".join(lines))

            stale_replacements = replace_ids - collisions
            if stale_replacements:
                raise ValidationError(
                    "replaceBaseModIds contains modIds that are not current "
                    "ATM10/extra collisions:\n"
                    + "\n".join(
                        f"  - {mod_id}"
                        for mod_id in sorted(stale_replacements)
                    )
                )

            # Determine whole ATM JARs removed by approved replacements.
            base_jars_to_replace: set[Path] = set()
            for mod_id in replace_ids:
                base_jars_to_replace.update(base_by_id[mod_id])

            # A single ATM JAR can provide several modIds. Removing the JAR is
            # safe only if the complete set remains provided by the extras.
            all_extra_ids = set(extra_by_id)
            for jar in sorted(base_jars_to_replace):
                missing_ids = set(base_by_jar[jar]) - all_extra_ids
                if missing_ids:
                    raise ValidationError(
                        f"Replacing ATM JAR {jar.name} would silently remove "
                        "additional modIds not supplied by minecraft/mods: "
                        + ", ".join(sorted(missing_ids))
                    )

            for jar in sorted(base_jars_to_replace):
                print(
                    "Replacing ATM JAR by approved modId collision: "
                    f"{jar.name}"
                )
                (out / jar.name).unlink()

            # A top-level opaque JAR has no modId metadata. Never overwrite one
            # merely because its filename happens to match.
            for extra_jar, ids in extra_by_jar.items():
                target = out / extra_jar.name
                if not ids and target.exists():
                    raise ValidationError(
                        "Opaque JAR filename collision between ATM10 and "
                        f"minecraft/mods: {extra_jar.name}"
                    )

            # Any remaining JAR filename collision is ambiguous. Approved
            # modId replacements have already removed their ATM JAR above.
            for extra_jar in extra_by_jar:
                if (out / extra_jar.name).exists():
                    raise ValidationError(
                        "JAR filename collision remains after applying the "
                        f"replacement policy: {extra_jar.name}"
                    )

            copy_directory_contents(extra, out)

            _, final_by_id = index(out)
            validate_unique("Final mods directory", final_by_id)

            print("")
            print("Minecraft mod-set validation succeeded.")
            print(f"  ATM JARs after removals: {len(base_by_jar)}")
            print(f"  Extra JARs:              {len(extra_by_jar)}")
            print(f"  Removed base JARs:       {len(remove_base_jars)}")
            print(f"  Replaced modIds:         {len(replace_ids)}")


        try:
            main()
        except ValidationError as exc:
            print("", file=sys.stderr)
            print("ERROR: Minecraft mod-set validation failed", file=sys.stderr)
            print(str(exc), file=sys.stderr)
            print("", file=sys.stderr)
            raise SystemExit(1)
      '';
    in
    pkgs.runCommand name {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
      set -euo pipefail
      mkdir -p "$out"

      python ${script} \
        ${baseMods} \
        ${extraMods} \
        "$out" \
        ${policy}
    '';
in
{
  inherit
    mkOverlayTree
    mkModSet
    ;
}
