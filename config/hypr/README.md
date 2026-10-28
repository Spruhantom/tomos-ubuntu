# Hyprland + Caelestia (experimental)

This folder adds a separate Hyprland session; the old Sway configuration is retained for rollback.

- `hyprland.conf`: PunkSway-themed Hyprland configuration.
- `scripts/install-caelestia.sh`: optional source checkout helper; it does not install guessed or unverified Ubuntu dependencies.

## Important compatibility note

Caelestia Shell upstream documents Arch, Nix and manual source installation. Its manual instructions require the git version of Quickshell and `caelestia-cli`. Ubuntu 26.04's packaged Hyprland/Qt stack may not match upstream expectations. Do not treat this as a working installer until built and tested on the exact Ubuntu release.

## Manual build outline

1. Install compatible Qt 6, CMake, Ninja and other dependencies listed in the upstream Caelestia Shell README.
2. Install a compatible git build of Quickshell and `caelestia-cli`.
3. Run `scripts/install-caelestia.sh` to clone the shell, then use the upstream CMake build/install steps.
4. Copy `config/hypr/hyprland.conf` to `~/.config/hypr/hyprland.conf` and select the Hyprland session at LightDM.
5. Test in a virtual machine before installing on hardware.

Upstream: https://github.com/caelestia-dots/shell
