## Install Nix and activate Home Manager

1. Install Nix
    ```bash
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
    ```
1. Install Developer tools
1. Edit the flake.nix and home.nix, change the username and architecure
1. Activate Home Manager
    ```bash
    mkdir -p $HOME/.config/nix/
    echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
    nix run home-manager -- switch --flake .#username
    ```

