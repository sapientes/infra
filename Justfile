default:
  @just --list --justfile {{justfile()}}

# Deploy config using deploy-rs
deploy host:
  NIXPKGS_ALLOW_UNFREE=1 deploy '.#{{host}}' -- --impure

# Edit a file using sops
sops file:
  sops {{file}}

# Update the keys from .sops.yaml for the file
updatekeys file:
  sops updatekeys {{file}}

