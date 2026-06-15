{
  lib,
  stdenv,
  zig,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "meowtd";
  version = "0.1.0";
  src = ../.;

  nativeBuildInputs = [ zig ];
  buildInputs = [ ];

  doCheck = false;
  checkPhase = ''
    runHook preCheck
    zig build test
    runHook postCheck
  '';

  meta = {
    homepage = "https://git.koi.rip/koi/meowtd";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.koi ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "meowtd";
  };
})
