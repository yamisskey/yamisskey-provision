{
  description = "Provisioning repository using Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      pkgs = import nixpkgs { };
    in
    {
      packages.x86_64-linux = let
        inherit (pkgs) callPackage;
      in {
        docker = callPackage ./nix/docker.nix { };
        docker-compose = callPackage ./nix/docker-compose.nix { };
      };

      homeConfigurations = {
        myHome = home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            ./home.nix
          ];
        };
      };

      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          self.packages.x86_64-linux.docker
          self.packages.x86_64-linux.docker-compose
        ];
      };
    };
}
