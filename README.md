# MeOwTD

securely send cute MOTDs to your (girl|enby|boy)friends' computers

## what is this

MeOwTD is intended to be used with SSH command restriction to give someone limited access to your
system MOTD file (usually `/etc/motd`)

it comes with an integrated CLI client for easy access :3

## how to set up

if you're on NixOS, the [flake](./flake.nix) contains a full [NixOS module](./nix/os-module.nix)
that you can use

there's also an [AUR package](https://aur.archlinux.org/packages/meowtd) for Arch users :3

on non-NixOS systems, theres two ways you can set up MeOwTD receiver.
you can either use the [setup bash script](./setup.sh) or do it manually

<details>
<summary>automated</summary>

1. clone the repository
2. run
   ```bash
   bash setup.sh install # to build and install the binaries (if not installed any other way)
   bash setup.sh user    # to set up the system user and permissions
   ```
3. configure authorized keys
   ```bash
   echo 'command="exec /usr/bin/meowtd-receive",restrict YOUR-SSH-PUBKEY' | tee -a /var/lib/meowtd/.ssh/authorized_keys
   ```
4. enable your SSH server with public key authentication

</details>
<details>
<summary>manual</summary>

1. install the `meowtd-receive` binary to `/usr/bin/meowtd-receive`
2. create the `mowtd` system user and group
   ```bash
   useradd --system --create-home --shell /bin/sh --home-dir /var/lib/meowtd --gid meowtd meowtd
   ```
3. set `/etc/motd` permissions
   ```bash
   chown root:meowtd /etc/motd
   chmod 0644 /etc/motd
   ```
4. configure authorized keys
   ```bash
   mkdir -p /var/lib/meowtd/.ssh
   echo 'command="exec /usr/bin/meowtd-receive",restrict YOUR-SSH-PUBKEY' | tee -a /var/lib/meowtd/.ssh/authorized_keys
   chown -R meowtd:meowtd /var/lib/meowtd
   chmod 0700 /var/lib/meowtd/.ssh
   chmod 0600 /var/lib/meowtd/.ssh/authorized_keys
   ```
5. enable public key authentication in your SSH server
6. make sure your SSH server is running

</details>

receiver functionality can be configured with the following environment variables

| name                | description                                      | default     |
|---------------------|--------------------------------------------------|-------------|
| `MEOWTD_PATH`       | absolute path to the motd file                   | `/etc/motd` |
| `MEOWTD_MAX_LENGTH` | maximum allowed message length (0 for unlimited) | `1024`      |

yay! you can now use a [configured](#client-configuration) MeOwTD client to connect and send a
message :3

```bash
meowtd 'hewwo wowld :3'
```

you can also optionally make your shell print the MOTD every time it's launched

<details>
<summary>example for ZSH</summary>

```zsh
# ~/.zshrc

if [[ -f /etc/motd ]] && [[ ! -o login ]]; then
  echo -ne '\e[2m'
  cat /etc/motd
  echo -ne '\e[0m'
fi
```

</details>

## client configuration

meowtd is configured with a json file in `$XDG_CONFIG_HOME/meowtd/config.json` usually
(`~/.config/meowtd/config.json`)

<details>
<summary>example configuration</summary>

```json
// comments are not allowed in actual json
// theyre added here for clarity
{
  "address": "your-ip-or-hostname",
  "port": 22,                                // optional (default: 22)
  "auth": {
    "username": "meowtd",                    // optional (default: meowtd)
    "key": {
      "private": "/path/to/your/ssh_key",
      "public": "/path/to/your/ssh_key.pub", // optional (default: private with the .pub suffix)
      "passphrase": "supersecretpassword67", // optional, insecure :c will be refactored later !
    }
  }
}
```

</details>

<hr>

<sub>Copyright 2026 june</sub>
