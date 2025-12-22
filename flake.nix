{
  description = "My Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      mkHome = { username, system, homeDirectory }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit username homeDirectory;
            pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
          };

          modules = [ ./home.nix ];
        };
    in {
      homeConfigurations = {
        "username1-macos" = mkHome {
          username = "username1";
          system = "aarch64-darwin";
          homeDirectory = "/Users/username1";
        };

        "wangle" = mkHome {
          username = "wangle";
          system = "x86_64-linux";
          homeDirectory = "/home/wangle";
        };
      };
    };
}
