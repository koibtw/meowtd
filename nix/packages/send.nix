{
  lib,
  stdenv,
  callPackage,
  pkg-config,
  libssh2,
  zig,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "meowtd";
  version = "0.1.0";
  src = ../..;

  buildInputs = [ libssh2 ];
  nativeBuildInputs = [
    pkg-config
    (callPackage ./hook.nix { })
    zig
  ];

  dontUseZigInstall = true;
  doCheck = false;

  zigBuildFlags = [ "meowtd" ];
  zigInstallStep = "meowtd";

  meta = {
    homepage = "https://git.koi.rip/koi/meowtd";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.koi ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "meowtd";
  };
})
