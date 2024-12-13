{
  hsm_ingress_secret_controller,
  cacert,
  nix2container,
}:

nix2container.buildImage {
  name = "hsm_ingress_secret_controller";

  config = {
    Entrypoint = [
      "${hsm_ingress_secret_controller}/bin/hsm_ingress_secret_controller"
    ];
    Env = [
      "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
