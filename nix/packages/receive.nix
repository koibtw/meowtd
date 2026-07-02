{
  lib,
  stdenv,
  callPackage,
  zig,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "meowtd-receive";
  version = "0.3.0";
  src = ../..;

  nativeBuildInputs = [
    zig
    (callPackage ./hook.nix { })
  ];

  dontUseZigInstall = true;
  doCheck = false;

  zigBuildFlags = [ "meowtd-receive" ];
  zigInstallStep = "meowtd-receive";

  meta = {
    homepage = "https://git.koi.rip/koi/meowtd";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.koi ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "meowtd-receive";
  };
})
