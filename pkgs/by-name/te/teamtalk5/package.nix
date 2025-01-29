{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  xar,
  cpio,
  alsa-lib,
  openssl,
  pulseaudio,
  libsForQt5,
  libX11,
  libXScrnSaver,
}:
let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system: ${stdenv.system}";
in
stdenv.mkDerivation (
  finalAttrs:
  let
    version = finalAttrs.version;
  in
  {
    pname = "teamtalk-client";
    version = "v5.17";

    src =
      rec {
        aarch64-darwin = fetchurl {
          url = "https://bearware.dk/teamtalk/${version}/TeamTalk_${version}_Setup.pkg";
          hash = "sha256-oSl9cw0/rnOiqjZy3UBLOB3++CZUoe/LeMFM/jfgyZM=";
        };
        # App is universal
        x86_64-darwin = aarch64-darwin;
        x86_64-linux = fetchurl {
          url = "https://bearware.dk/teamtalk/${version}/teamtalk-${version}-ubuntu22-x86_64.tgz";
          hash = "sha256-+M42U4cTm3fOysbqN+ff3//IatFGxM1AaxzzEEAzPqI=";
        };
      }
      .${stdenv.system} or throwSystem;

    dontUnpack = stdenv.hostPlatform.isLinux;
    unpackPhase = lib.optionalString stdenv.hostPlatform.isDarwin ''
      xar -xf $src
      zcat < dk.bearware.TeamTalk5.pkg/Payload | cpio -i
    '';

    installPhase = ''
      runHook preInstall
      ${
        rec {
          aarch64-darwin = ''
            mkdir -p $out/Applications
            cp -R TeamTalk5.app $out/Applications/
          '';
          # darwin steps same on both architectures
          x86_64-darwin = aarch64-darwin;
          x86_64-linux = ''
            mkdir $out
            tar -C $out -xf $src
            mv $out/teamtalk-${version}-ubuntu22-x86_64/client $out/
            mv $out/teamtalk-${version}-ubuntu22-x86_64/License.txt $out/
            rm -rf $out/teamtalk-${version}-ubuntu22-x86_64
          '';
        }
        .${system} or throwSystem
      }
      runHook postInstall
    '';

    postFixup =
      lib.optionalString stdenv.hostPlatform.isDarwin ''
        makeWrapper $out/Applications/TeamTalk5.app/Contents/MacOS/TeamTalk5 $out/bin/teamtalk
      ''
      + lib.optionalString stdenv.hostPlatform.isLinux ''
        makeWrapper $out/client/teamtalk5 $out/bin/teamtalk
      '';

    # QT_DEBUG_PLUGINS = 1;
    # QT_QPA_PLATFORM_PLUGIN_PATH = "${qt5.qtbase.bin}/lib/qt-${qt5.qtbase.version}/plugins/platforms";
    qtWrapperArgs = [
      "--set QT_DEBUG_PLUGINS 1"
      "--set QT_QPA_PLATFORM_PLUGIN_PATH ${libsForQt5.qtbase.bin}/lib/qt-${libsForQt5.qtbase.version}/plugins/platforms"
    ];

    buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
      alsa-lib
      openssl
      pulseaudio
      libsForQt5.qtspeech
      libsForQt5.qtmultimedia
      libsForQt5.qtx11extras
      libsForQt5.qtbase
      libX11
      libXScrnSaver
    ];

    nativeBuildInputs =
      [
        makeWrapper
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        autoPatchelfHook
        libsForQt5.wrapQtAppsHook
      ]
      ++ lib.optionals stdenv.hostPlatform.isDarwin [
        xar
        cpio
      ];

    # passthru.updateScript = lib.getExe (writeShellApplication {
    #   name = "teamtalk5-update-script"
    #   text = throw "TODO";
    # });

    meta = {
      description = "Freeware conferencing system";
      homepage = "https://bearware.dk";
      license = lib.licenses.unfree;
      maintainers = with lib.maintainers; [
        _347Online
      ];
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  }
)
