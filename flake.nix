{
  description = "Graphical console greeter for greetd with ASCII art and themes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    niri.url = "github:kagurazakei/niri";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      niri,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.default = pkgs.callPackage ./default.nix { };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go_1_25
            gnumake
            git
          ];

          shellHook = ''
            echo "sysc-greet development environment"
            echo "Run 'make build' to build the greeter"
            echo "Run 'make test' to test in test mode"
          '';
        };
      }
    )
    // {
      nixosModules.default = import ./module.nix;
    };
}
