{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    ocaml-overlay.url = "github:nix-ocaml/nix-overlays";
    ocaml-overlay.inputs.nixpkgs.follows = "nixpkgs";
    nix-filter.url = "github:numtide/nix-filter";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix2container,
      ocaml-overlay,
      nix-filter,
      devenv,
    }@inputs:
    let
      # The set of systems to provide outputs for
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # A function that provides a system-specific Nixpkgs for the desired systems
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f rec {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ ocaml-overlay.overlays.default ];
            };
            nix2containerPkgs = nix2container.packages.${system};
            ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_2;
          }
        );
    in
    {
      nixosModules.default = ./nix/module.nix;
      packages = forEachSystem (
        {
          system,
          pkgs,
          nix2containerPkgs,
          ocamlPackages,
        }:
        let
          openapi_packages = (ocamlPackages.callPackage ./nix/openapi.nix { });
          msal = ocamlPackages.callPackage ./nix/msal.nix {
            nix-filter = nix-filter.lib;
          };
        in
        rec {
          inherit msal openapi_packages;

          devenv-up = self.devShells.${system}.default.config.procfileScript;
          devenv-test = self.devShells.${system}.default.config.test;

          hsm_ingress_secret_controller = ocamlPackages.callPackage ./nix {
            inherit (openapi_packages) openapi ppx_deriving_json_schema;
            inherit msal;
            nix-filter = nix-filter.lib;
            static = true;
          };

          container = pkgs.callPackage ./nix/container.nix {
            inherit (nix2containerPkgs) nix2container;
            inherit hsm_ingress_secret_controller;
          };

          default = hsm_ingress_secret_controller;
        }
      );

      devShells = forEachSystem (
        {
          system,
          pkgs,
          ocamlPackages,
          ...
        }:
        {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              (import ./nix/devenv/env.nix)
              (import ./nix/devenv/scripts.nix)
              (import ./nix/devenv/test.nix {
                inherit pkgs;
                container = self.packages.${system}.container;
              })
              (import ./nix/devenv/git-hooks.nix)
              (import ./nix/devenv/languages.nix { inherit ocamlPackages; })
              (import ./nix/devenv/packages.nix { inherit pkgs self system; })
              (import ./nix/devenv)
            ];
          };
        }
      );
    };
}
