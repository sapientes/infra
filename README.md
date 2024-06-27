# sapientes-infra

## Installation of NixOS on new machines

Create a new VM using Oracle Linux **7.9**.  
Then, run the following commands:

```bash
ssh opc@$host "curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.11 sudo bash -x"
# wait until installed
scp root@${host}:/etc/nixos/hardware-configuration.nix $host/hardware-configuration.nix
```

