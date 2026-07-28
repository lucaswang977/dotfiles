{
  description = "My Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      
      mkHome = { username, system, homeDirectory }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit username homeDirectory;
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
