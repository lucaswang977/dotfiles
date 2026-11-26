{ pkgs, username, homeDirectory, lib, ... }:

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
    pkgs.llvmPackages.clang-unwrapped
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
    pkgs.nodejs_22
    pkgs.yarn
    pkgs.rustup
    pkgs.poetry
    pkgs.aichat
    pkgs.sshs
    pkgs.lynx
    pkgs.github-cli
    pkgs.uv
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

  home.file.".tmux.conf" = {
    source = ./tmux/tmux.conf;
  };

  # tmux ステータスバーのシステムモニタ (tmux.conf の status-right から呼ばれる)
  home.file.".local/bin/tmux-status" = {
    source = ./tmux/status.sh;
    executable = true;
  };

  # デスクトップ通知を監視して、tmux のステータスバー用にファイルへ書き出す (tmux.conf の run-shell から起動される)
  home.file.".local/bin/tmux-notify" = {
    source = ./tmux/notify.py;
    executable = true;
  };

  home.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
  };
}
