{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  xar,
  cpio,
}:
let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system: ${stdenv.system}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "teamtalk5";
  version = "v5.17";

  src =
    let
      version = finalAttrs.version;
    in
    rec {
      aarch64-darwin = fetchurl {
        url = "https://bearware.dk/teamtalk/${version}/TeamTalk_${version}_Setup.pkg";
        name = "TeamTalk_${version}_Setup.pkg";
        hash = "sha256-oSl9cw0/rnOiqjZy3UBLOB3++CZUoe/LeMFM/jfgyZM=";
      };
      # App is universal
      x86_64-darwin = aarch64-darwin;
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
      }
      .${system} or throwSystem
    }
    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    makeWrapper $out/Applications/TeamTalk5.app/Contents/MacOS/TeamTalk5 $out/bin/teamtalk
  '';

  nativeBuildInputs =
    [
      makeWrapper
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
    description = "TeamTalk 5 is a freeware conferencing system which allows multiple users to participate in audio and video conversations.";
    homepage = "https://bearware.dk";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      _347online
    ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
