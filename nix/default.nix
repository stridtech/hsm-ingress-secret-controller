{
  buildDunePackage,
  ocamlPackages,
  nix-filter,
  ppx_deriving_json_schema,
  openapi,
  static,
  msal,
}:

buildDunePackage {
  pname = "azure";
  version = "1.0.0";

  src = nix-filter {
    root = ../.;
    # If no include is passed, it will include all the paths.
    include = [
      # Include the "src" path relative to the root.
      "src"
      # Include this specific path. The path must be under the root.
      ../azure.opam
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
    fmt
    base64
    msal

    openapi

    ppx_deriving
    ppx_deriving_json_schema
    ppx_deriving_yojson
  ];

  buildPhase = ''
    runHook preBuild
    echo "running ${if static then "static" else "release"} build"
    dune build ./src/bin/akv_cert_secret.exe --display=short --profile=${
      if static then "static" else "release"
    }
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp _build/default/src/bin/akv_cert_secret.exe $out/bin/akv_cert_secret

    runHook postInstall
  '';
}
