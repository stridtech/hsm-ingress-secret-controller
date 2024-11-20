{ buildDunePackage, ocamlPackages }:

buildDunePackage {
  pname = "azure";
  version = "1.0.0";

  src = ../.;

  buildInputs = with ocamlPackages; [
    jose
    piaf
    eio
    yojson
    uri
    logs
    fmt

    ppx_deriving
    ppx_deriving_yojson
  ];
}
