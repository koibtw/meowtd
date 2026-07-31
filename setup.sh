#!/usr/bin/env bash

set -euo pipefail

KEYS_FILE='/etc/ssh/authorized_keys.d/meowtd'
MOTD_PATH='/etc/motd'
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
    [[ $(command -v "$cmd") ]] || die 'required command not found' "$cmd"
  done
}

check_lib() {
  local libraries=("$@")

  for lib in "${libraries[@]}"; do
    pkg-config "$lib" || die 'required library not found' "$lib"
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

  local help_cmd=("$0" user)
  info 'set up the system user and permissions by running' "${help_cmd[*]}"
}

do_user() {
  check_env 'groupadd' 'useradd'

  if [[ ! -x /bin/sh ]]; then
    die 'shell not found or is not executable' '/bin/sh'
  fi

  info 'creating system user and group'
  groupadd meowtd
  useradd \
    --system \
    --no-create-home \
    --shell /bin/sh \
    --gid meowtd \
    meowtd

  if [[ ! -f "$MOTD_PATH" ]]; then
    info 'creating' "$MOTD_PATH"
    touch "$MOTD_PATH"
  fi

  info 'setting MOTD permissions'
  chown root:meowtd "$MOTD_PATH"
  chmod 0664 /etc/motd

  local help_cmd=("$0" add-key \'YOUR-SSH-PUBKEY\')
  info 'add authorized keys by running' "${help_cmd[*]}"
}

do_add_key() {
  local key="$1"

  if [[ ! -f "$KEYS_FILE" ]]; then
    info 'creating' "$KEYS_FILE"
    touch "$KEYS_FILE"
  fi

  [[ $(grep -sc "$key\$" "$KEYS_FILE") -eq '0' ]] || die 'key already in' "$KEYS_FILE"

  info 'appending to' "$KEYS_FILE"
  echo "command=\"exec /usr/bin/meowtd-receive\",restrict $key" >>"$KEYS_FILE"
}

do_remove_key() {
  local key="$1"
  local escaped

  [[ $(grep -sc "$key\$" "$KEYS_FILE") -gt '0' ]] || die 'key not in' "$KEYS_FILE"

  info 'removing from' "$KEYS_FILE"
  escaped="$(echo "$key" | sed -e 's/[\/&]/\\&/g')"
  sed -i "/$escaped\$/d" "$KEYS_FILE"
}

run() {
  local cmd="$1"
  local arg="$2"

  case "$cmd" in
  install) do_install ;;
  user) do_user ;;
  add-key) do_add_key "$arg" ;;
  remove-key) do_remove_key "$arg" ;;
  *) die "invalid command: $cmd" ;;
  esac
}

check_root
run "${1:-}" "${2:-}"
info 'done :3'
