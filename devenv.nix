{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_2;
  akv_cert_secret = ocamlPackages.callPackage ./nix { };
in
{
  # https://devenv.sh/languages/
  languages.nix.enable = true;
  languages.ocaml.enable = true;
  languages.ocaml.packages = ocamlPackages;

  env = {
    AKV = "stab-dev-akv-01";
    CERTIFICATE = "stab-dev-akvc-01";
  };

  # https://devenv.sh/processes/
  processes = {
    # format.exec = "${pkgs.watchexec}/bin/watchexec -e ml,dune -- dune build @fmt --auto-promote";
    build.exec = "${pkgs.watchexec}/bin/watchexec -e ml,dune -- dune build ./src/bin/akv_cert_secret";
    # akv_cert_secret.exec = "dune exec src/bin/akv_cert_secret.exe";
  };

  scripts = {
    akv_cert.exec = "${akv_cert_secret}/bin/akv_cert_secret";
    run-with-token.exec = ''
      export AKV_ACCESS_TOKEN=$(az account get-access-token --resource https://vault.azure.net --query accessToken --output tsv)
      dune exec src/bin/akv_cert_secret.exe -- --akv "$AKV" --name "$CERTIFICATE"
    '';
  };

  containers."prod" = {
    name = "akv-cert-secret";
    copyToRoot = "${akv_cert_secret}";
    startupCommand = "ls && ls /bin";
  };

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/

  # enterShell = ''
  #   git --version
  # '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/

  packages =
    with ocamlPackages;
    [
      jose
      piaf
      eio
      yojson
      uri
      logs
      fmt

      ppx_deriving
      ppx_deriving_yojson
    ]
    ++ (with pkgs; [
      azure-cli
      git
    ]);
}
