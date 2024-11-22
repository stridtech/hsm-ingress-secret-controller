{
  buildDunePackage,
  ocamlPackages,
  fetchFromGitHub,
  lib,
}:

rec {
  openapi = buildDunePackage rec {
    pname = "openapi";
    version = "1.0.1";

    src = fetchFromGitHub {
      owner = "jhuapl-saralab";
      repo = "openapi-ocaml";
      rev = "v${version}";
      hash = "sha256-C7DKEAYNejGSg6M258Snj0iglJ7bEA5FD2+5vDUQsZc=";
    };

    buildInputs = with ocamlPackages; [
      yojson
      core
      ppx_yojson_conv
      ppx_yojson_conv_lib
      ppx_deriving
    ];
  };

  ppx_deriving_json_schema = buildDunePackage {
    inherit (openapi) version src;
    pname = "ppx_deriving_json_schema";

    buildInputs = with ocamlPackages; [
      ppx_deriving
      ppxlib
      yojson
      # openapi
    ];

    propagatedBuildInputs = with ocamlPackages; [
      ppx_yojson_conv_lib
      core
    ];
  };
}
