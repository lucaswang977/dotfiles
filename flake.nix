{
  description = "My Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixgl.url = "github:nix-community/nixGL";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixgl, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      
      mkHome = { username, system, homeDirectory }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ nixgl.overlay ];
          };
          
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit username homeDirectory pkgs-unstable;
          };

          modules = [ ./home.nix ];
        };
    in {
      homeConfigurations = {
        "wanglei" = mkHome {
          username = "wanglei";
          system = "aarch64-darwin";
          homeDirectory = "/Users/wanglei";
        };

        "wangle" = mkHome {
          username = "wangle";
          system = "x86_64-linux";
          homeDirectory = "/home/wangle";
        };
      };
    };
}
