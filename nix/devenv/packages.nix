{
  pkgs,
  self,
  system,
}:

let
  getDeps =
    inputPackage:
    pkgs.lib.unique (
      builtins.concatMap (pkg: pkg.propagatedBuildInputs ++ pkg.buildInputs) inputPackage
    );
in
{
  packages =
    (getDeps (
      with self.packages.${system};
      [
        msal
        hsm_ingress_secret_controller
      ]
    ))
    ++ (with pkgs; [
      kubernetes-helm
      azure-cli
      git
    ]);
}
