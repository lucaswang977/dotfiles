## Environment Setup

### Install Font
1. Use Monaspice Nerd Font
1. Install from [here](https://www.nerdfonts.com/font-downloads)
1. Setup the terminal emulator (font etc.)

### Install Nix and activate Home Manager

1. Install Nix
    ```bash
    sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
    ```
1. Install Developer tools
1. Edit the flake.nix and home.nix, change the username and architecure
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
    rm ~/.config/tmux
    ```
1. Activate Home Manager
    ```bash
    mkdir -p $HOME/.config/nix/
    echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
    nix run home-manager -- switch --flake .#username
    ```

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

### On WebAI-to-API
1. Enable the Python 3.11+
```bash
poetry env use python3.11
```

2. Clone the repo
```bash
git clone https://github.com/Amm1rr/WebAI-to-API.git
```

3. Install the dependencies
```bash
poetry install
```

4. Update the config file
```bash
cp config.conf.example config.conf

# gemini_cookie_1psid =
# gemini_cookie_1psidts =
```

5. Start the server
```bash
poetry run python src/run.py
```
