{
  lib,
  stdenvNoCC,
  fetchurl,
  jre,
}:

let
  version = "1.20.1-47.4.22";
  forgeDirectory = "libraries/net/minecraftforge/forge/${version}";
in
stdenvNoCC.mkDerivation {
  pname = "forge-server";
  inherit version;

  src = fetchurl {
    url = "https://maven.minecraftforge.net/net/minecraftforge/forge/${version}/forge-${version}-installer.jar";
    hash = "sha256-pmuV5n66az9yBHqnMxjkuA7bYW1YNM0FpbquENJWmdY=";
  };

  dontUnpack = true;
  preferLocalBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/minecraft"
    cp -v "$src" "$out/lib/minecraft/installer.jar"

    cat > "$out/bin/minecraft-server" <<EOF
    #!${stdenvNoCC.shell}
    set -eu

    forge_directory="${forgeDirectory}"
    args_file="${forgeDirectory}/unix_args.txt"

    if [ -f "\$args_file" ]; then
      echo "Forge ${version} is already installed."
    else
      echo "Installing Forge ${version}..."
      ${lib.getExe jre} \
        -jar "$out/lib/minecraft/installer.jar" \
        --installServer
    fi

    if [ ! -f "\$args_file" ]; then
      echo "Forge installation failed: \$args_file was not created." >&2
      exit 1
    fi

    echo "Running Forge ${version}..."

    exec ${lib.getExe jre} \
      "\$@" \
      @"\$args_file" \
      nogui
    EOF

    chmod +x "$out/bin/minecraft-server"

    runHook postInstall
  '';

  meta = {
    description = "Forge ${version} Minecraft server";
    homepage = "https://minecraftforge.net";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.unix;
    mainProgram = "minecraft-server";
  };
}