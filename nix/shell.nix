{
  shellcheck,
  mkShellNoCC,
  zig_0_16,
  zls_0_16,
  pkg-config,
  libssh2,
}:
mkShellNoCC {
  packages = [
    shellcheck
    zig_0_16
    zls_0_16
    pkg-config
    libssh2
  ];
}
