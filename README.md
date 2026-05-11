## Environment Setup

### Install Nix and activate Home Manager

1. Install Nix
    ```bash
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
    ```
1. Install Developer tools
1. Edit the flake.nix and home.nix, change the username and architecure
1. Install the [Ghostty](https://ghostty.org/docs/install/binary)
1. Remove the local config files.
    ```bash
    rm -rf .local/state/nvim
    rm -rf .local/share/nvim
    rm -rf .cache/nvim
    rm ~/.bashrc
    rm ~/.zshrc
    rm ~/.profile
    rm ~/.zshenv
    rm ~/.config/starship.toml
    rm ~/.config/ghostty
    ```
1. Activate Home Manager
    ```bash
    mkdir -p $HOME/.config/nix/
    echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
    nix run home-manager -- switch --flake .#username
    ```

### On Font
1. Use Monaspice Nerd Font
1. Install from [here](https://www.nerdfonts.com/font-downloads)

### On Flutter
1. Install a specified version of Flutter
```bash
fvm install 3.10.6
```

2. Set it as a global default setting
```bash
fvm global 3.10.6
```

3. Make sure the flutter is well installed
```bash
fvm flutter doctor
```
