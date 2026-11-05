## Environment Setup

### Install Nix and activate the Home Manager
1. Install tools 
  - build-essentials (for neovim plugins)
  - git, curl
2. Install Nix
    ```bash
    curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
    ```
3. Edit the flake.nix and home.nix, change the username and architecure
4. Remove the local config files.
    ```bash
    rm -rf .local/state/nvim
    rm -rf .local/share/nvim
    rm -rf .cache/nvim
    rm ~/.bashrc
    rm ~/.zshrc
    rm ~/.profile
    rm ~/.zshenv
    rm ~/.config/starship.toml
    rm ~/.config/tmux
    ```
5. Activate Home Manager
    ```bash
    mkdir -p $HOME/.config/nix/
    echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
    nix run home-manager -- switch --flake .#username
    ```
6. Set zsh as the default shell
    ```bash
    which zsh
    echo "$(which zsh)" | sudo tee -a /etc/shells
    cat /etc/shells
    chsh -s "$(which zsh)"
    # reboot or relogin is needed
    echo $SHELL
    ```

### (Optional) Install the NERD Font
1. Use Monaspice Nerd Font
2. Install from [here](https://www.nerdfonts.com/font-downloads)
3. Setup the terminal emulator (font etc.)
