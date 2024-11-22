{
  akv_cert_secret,
  cacert,
  nix2container,
}:

nix2container.buildImage {
  name = "akv_cert_secret";

  config = {
    Entrypoint = [
      "${akv_cert_secret}/bin/akv_cert_secret"
    ];
    Env = [
      "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };
}
