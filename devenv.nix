{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_5_2;
  openapi_packages = (ocamlPackages.callPackage ./nix/openapi.nix { });

in
{
  # https://devenv.sh/languages/
  languages.nix.enable = true;
  languages.ocaml.enable = true;
  languages.ocaml.packages = ocamlPackages;

  env = {
    AKV = "stab-dev-akv-01";
    CERTIFICATE = "stab-dev-akvc-01";
    DEV_REGISTRY_NAME = "stabdevacr01";
    DEV_SUBSCRIPTION = "732f9144-d159-43d8-b45f-87dca97af938";
    IMAGE_REPO = "akv-cert-secret";
  };

  # https://devenv.sh/processes/
  processes = {
    build.exec = "${pkgs.watchexec}/bin/watchexec -e ml,dune -- dune build -p azure";
  };

  # https://devenv.sh/scripts/
  scripts =
    let
      utils = ''
        get_newest_pod() {
          local namespace="$1"
          local newest_pod
          newest_pod=$(kubectl get pods -n "$namespace" --sort-by=.metadata.creationTimestamp --output=jsonpath="{.items[-1].metadata.name}")
          echo "$newest_pod"
        }

        # Function to tail logs for a pod
        tail_pod_logs() {
          local namespace="$1"
          local pod_name="$2"

          kubectl logs -f -n "$namespace" "$pod_name"          
        }
      '';
      ensure_subscription = ''
        # Make sure we're in the dev subscription
        CURRENT_SUBSCRIPTION="$(az account list --query "[?isDefault].id" --output tsv)"

        if [ "$CURRENT_SUBSCRIPTION" != "$DEV_SUBSCRIPTION" ]; then
            echo "Switching to subscription: $DEV_SUBSCRIPTION"
            az account set --subscription "$DEV_SUBSCRIPTION"
        else
            echo "Already using correct subscription: $DEV_SUBSCRIPTION"
        fi
      '';
    in
    {
      run-with-token.exec = ''
        export AKV_ACCESS_TOKEN=$(az account get-access-token --resource https://vault.azure.net --query accessToken --output tsv)
        dune exec ./src/bin/akv_cert_secret.exe --akv "$AKV" --name "$CERTIFICATE"
      '';
      deploy-dev.exec = ''
        set -e
        ${utils}

        nix build .#container

        ${ensure_subscription}

        # TODO: Can we move this to be a "compound variable"?
        IMAGE_NAME="$DEV_REGISTRY_NAME.azurecr.io/$IMAGE_REPO"

        latest_tag=$(az acr repository show-tags --repository $IMAGE_REPO --name $DEV_REGISTRY_NAME --output tsv | sort -g | tail -n1)
        tag=$((latest_tag + 1))
        final_image="$IMAGE_NAME:$tag"

        az acr login --name $DEV_REGISTRY_NAME
        nix run .\#container.copyTo -- "docker://$final_image"

        sed -i "s;azurecr.io/akv-cert-secret:.*;azurecr.io/akv-cert-secret:$tag;" ./manifests/main.yaml

        kubectl apply -f ./manifests/main.yaml

        sleep 5

        newest_pod=$(get_newest_pod kube-system)
        tail_pod_logs kube-system "$newest_pod"
      '';
    };

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # enterShell = ''
  #   git --version
  # '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  git-hooks.hooks = {
    shellcheck.enable = true;
    dune-fmt.enable = true;
  };

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

      openapi_packages.openapi
      openapi_packages.ppx_deriving_json_schema

      # tools
      ocaml_openapi_generator
    ]
    ++ (with pkgs; [
      azure-cli
      git
    ]);
}
