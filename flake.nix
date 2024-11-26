{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    ocaml-overlay.url = "github:nix-ocaml/nix-overlays";
    ocaml-overlay.inputs.nixpkgs.follows = "nixpkgs";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix2container,
      ocaml-overlay,
      nix-filter,
    }:
    let
      # The set of systems to provide outputs for
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # A function that provides a system-specific Nixpkgs for the desired systems
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs allSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ ocaml-overlay.overlays.default ];
            };
            nix2containerPkgs = nix2container.packages.${system};
          }
        );
    in
    {
      nixosModules.default = ./nix/module.nix;
      packages = forAllSystems (
        {
          system,
          pkgs,
          nix2containerPkgs,
        }:
        let
          openapi_packages = (pkgs.ocaml-ng.ocamlPackages_5_2.callPackage ./nix/openapi.nix { });
          msal = pkgs.ocaml-ng.ocamlPackages_5_2.callPackage ./nix/msal.nix {
            nix-filter = nix-filter.lib;
          };
        in
        rec {
          inherit msal;
          akv_cert_secret = pkgs.ocaml-ng.ocamlPackages_5_2.callPackage ./nix {
            inherit (openapi_packages) openapi ppx_deriving_json_schema;
            inherit msal;
            nix-filter = nix-filter.lib;
            static = true;
          };
          container = pkgs.callPackage ./nix/container.nix {
            inherit (nix2containerPkgs) nix2container;
            inherit akv_cert_secret;
          };
          default = akv_cert_secret;
        }
      );
    };
}
