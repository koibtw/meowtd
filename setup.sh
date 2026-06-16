#!/usr/bin/env bash

set -euo pipefail

COLON='\e[2m:\e[0m'

die() {
  local msg="$1"
  local extra="${2:-}"

  if [[ -n "$extra" ]]; then
    printf '%b%b %s: %b%s%b\n' '\e[1;31merror\e[0m' "$COLON" "$msg" '\e[2m' "$extra" '\e[0m'
  else
    printf '%b%b %s\n' '\e[1;31merror\e[0m' "$COLON" "$msg"
  fi

  exit 1
}

info() {
  local msg="$1"
  local extra="${2:-}"

  if [[ -n "$extra" ]]; then
    printf '%b%b %s: %b%s%b\n' '\e[1;32minfo\e[0m' "$COLON" "$msg" '\e[2m' "$extra" '\e[0m'
  else
    printf '%b%b %s\n' '\e[1;32minfo\e[0m' "$COLON" "$msg"
  fi
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    die 'this script needs to be run as root'
  fi
}

check_env() {
  local commands=("$@")

  for cmd in "${commands[@]}"; do
    [[ $(command -v "$cmd") ]] || die "required command not found: $cmd"
  done
}

check_lib() {
  local libraries=("$@")

  for lib in "${libraries[@]}"; do
    pkg-config "$lib" || die "required library not found: $lib"
  done
}

do_install() {
  local run_cmd

  check_env 'zig' 'pkg-config'
  check_lib 'libssh2'

  info 'building binaries'
  run_cmd=(zig build -Dcpu=baseline --release=safe)
  "${run_cmd[@]}" || die 'building failed. try running' "${run_cmd[*]}"

  info 'installing binaries'
  run_cmd=(zig build install -Dcpu=baseline --release=safe --prefix /usr)
  "${run_cmd[@]}" || die 'installation failed. try running' "${run_cmd[*]}"
}

do_user() {
  check_env 'useradd'

  if [[ ! -x /bin/sh ]]; then
    die 'shell not found or is not executable: /bin/sh'
  fi

  info 'creating system user and group'
  useradd \
    --system \
    --create-home \
    --shell /bin/sh \
    --home-dir /var/lib/meowtd \
    --gid meowtd \
    meowtd

  if [[ ! -f /etc/motd ]]; then
    info 'creating' '/etc/motd'
    touch /etc/motd
  fi

  info 'setting MOTD permissions'
  chown root:meowtd /etc/motd
  chmod 0644 /etc/motd

  info 'creating SSH config files'
  mkdir -p /var/lib/meowtd/.ssh
  touch /var/lib/meowtd/.ssh/authorized_keys
  chown -R meowtd:meowtd /var/lib/meowtd
  chmod 0700 /var/lib/meowtd/.ssh
  chmod 0600 /var/lib/meowtd/.ssh/authorized_keys

  local help_cmd=(echo 'command="exec /usr/bin/meowtd-receive",restrict YOUR-SSH-PUBKEY' '|' tee -a /var/lib/meowtd/.ssh/authorized_keys)
  info 'add authorized keys by running' "${help_cmd[*]}"
}

run() {
  local cmd="$1"

  case "$cmd" in
  install) do_install ;;
  user) do_user ;;
  *) die "invalid command: $cmd" ;;
  esac
}

check_root
run "${1:-}"
info 'done :3'
