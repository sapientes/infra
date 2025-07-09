# sapientes-infra

This repository contains the configuration for all sapientes servers.  
It's built on top of deploy-rs and [oskardotglobal/bienenstock](https://github.com/oskardotglobal/bienenstock)

## Basic usage

Commonly used commands can be found inside the Justfile.
We use sops-nix for secret management, so your private key will have to be added by another admin
before you can deploy.

## CI

We use garnix.io for CI. On push, the NixOS configurations and flake checks will be evaluated by them.

## Installation of NixOS on new machines

Create a new VM using Oracle Linux **7.9**.  
Then, run the following commands:

```bash
ssh opc@$host "curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.11 sudo bash -x"
# wait until installed
scp root@${host}:/etc/nixos/hardware-configuration.nix $host/hardware-configuration.nix
```

