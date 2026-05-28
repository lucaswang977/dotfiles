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
    pkgs.bottom
    pkgs.fzf
    pkgs.tmux
    pkgs.fd
    pkgs.ripgrep
    pkgs.lazygit
    pkgs.yazi
    pkgs.zsh-fzf-tab
    pkgs.starship
    pkgs.ssh-copy-id
    pkgs.aider-chat
    pkgs.nodejs_22
    pkgs.yarn
    pkgs.rustup
    pkgs.poetry
    pkgs-unstable.fvm
  ]
  ++ (if isLinux then [
    pkgs.xclip
  ] else []);
  
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    bash.enable = true; # see note on other shells below
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
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./tmux/tmux.conf;
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

  home.file.".aider.conf.yml" = {
    source = ./aider/aider.conf.yml;
  };

  home.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
    FVM_SKIP_SHELL_COMPLETIONS = "true";
  };
}
