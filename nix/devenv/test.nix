# https://devenv.sh/tests/
{ pkgs, container }:
{
  enterTest = ''
    echo "Running tests"
    ${pkgs.kubernetes-helm}/bin/helm lint ./charts/hsm-ingress-secret-controller

    nix run .#container.copyToDockerDaemon
    ${pkgs.trivy}/bin/trivy image ${container.imageName}:${container.imageTag}
  '';
}
