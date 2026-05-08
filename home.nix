{ pkgs, pkgs-unstable, username, homeDirectory, ... }:

let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "25.11";

  xdg.enable = true;

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.packages = [
    pkgs.home-manager
    pkgs.git
    pkgs.neovim
    pkgs.tree-sitter
    pkgs.eza
    pkgs.bat
    pkgs.bottom
    pkgs.fzf
    pkgs.fd
    pkgs.nodejs_22
    pkgs.ripgrep
    pkgs.lazygit
    pkgs.yazi
    pkgs.starship
    pkgs.zsh-fzf-tab
    pkgs-unstable.fvm
    pkgs.yarn
    pkgs.ssh-copy-id
  ]
  ++ (if isLinux then [
    pkgs.xclip
    pkgs.nixgl.auto.nixGLDefault
  ] else []);
  
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    bash.enable = true; # see note on other shells below
  };

  programs.ghostty = {
    enable = true;
    # Using pkgs-unstable ensures you get the latest Ghostty features
    package = if isLinux then 
                pkgs-unstable.ghostty 
              else 
                pkgs-unstable.ghostty; 

    enableZshIntegration = true;
    settings = {
      theme = "Catppuccin Macchiato";
      font-size = 12;
      font-family = "MonaspiceAr Nerd Font Mono";
      macos-option-as-alt = pkgs.lib.mkIf isDarwin "left";
      unfocused-split-opacity = 0.8;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "z"
        "git"
        "vi-mode"
      ];
    };
    
    initContent = builtins.readFile ./zsh/zshrc;

    shellAliases = {
      ghostty = if isLinux then "nixGL ghostty" else "ghostty";
    };
  };
  
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./starship/starship.toml);
  };

  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };

  xdg.configFile."yazi" = {
    source = ./yazi;
    recursive = true;
  };

  home.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
    FVM_SKIP_SHELL_COMPLETIONS = "true";
  };
}
