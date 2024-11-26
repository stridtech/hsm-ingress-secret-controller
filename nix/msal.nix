{
  buildDunePackage,
  ocamlPackages,
  nix-filter,
}:

buildDunePackage {
  pname = "msal";
  version = "1.0.0";

  src = nix-filter {
    root = ../.;
    # If no include is passed, it will include all the paths.
    include = [
      # Include the "src" path relative to the root.
      "src/msal"
      # Include this specific path. The path must be under the root.
      ../msal.opam
      ../dune-project
      # Include all files with the .js extension
      (nix-filter.matchExt "ml")
      (nix-filter.matchExt "dune")
    ];
  };

  buildInputs = with ocamlPackages; [
    jose
    piaf
    eio
    yojson
    uri
    logs
  ];
}
