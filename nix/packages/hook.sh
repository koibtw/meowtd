# Copyright (c) 2003-2026 Eelco Dolstra and the Nixpkgs/NixOS contributors
# Source: pkgs/development/compilers/zig/setup-hook.sh
# Revision: e20232eab6909f5218da6c8919d155538cca25fb
# Modified

# shellcheck shell=bash

function zigInstallPhase {
  runHook preInstall

  local buildCores=1

  # Parallel building is enabled by default.
  if [ "${enableParallelInstalling-1}" ]; then
    buildCores="$NIX_BUILD_CORES"
  fi

  local flagsArray=(
    "-j$buildCores"
  )

  concatTo flagsArray \
    zigBuildFlags zigBuildFlagsArray \
    zigInstallFlags zigInstallFlagsArray

  if [ -z "${dontSetZigDefaultFlags:-}" ]; then
    concatTo flagsArray \
      zigDefaultCpuFlag zigDefaultOptimizeFlag
  fi

  if [ -z "${dontAddPrefix-}" ] && [ -n "$prefix" ]; then
    # Zig does not recognize `--prefix=/dir/`, only `--prefix /dir/`
    flagsArray+=("${prefixKey:---prefix}" "$prefix")
  fi

  echoCmd 'zig install flags' "${flagsArray[@]}"
  TERM=dumb zig build "${zigInstallStep:-install}" "${flagsArray[@]}" --verbose

  runHook postInstall
}

installPhase=zigInstallPhase
