# https://devenv.sh/scripts/
{ ... }:
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
  scripts = {
    run-with-token.exec = ''
      export AKV_ACCESS_TOKEN=$(az account get-access-token --resource https://vault.azure.net --query accessToken --output tsv)
      dune exec ./src/bin/hsm_ingress_secret_controller.exe --akv "$AKV" --name "$CERTIFICATE"
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
}
