## HSM Ingress secret controller

This controller is supposed to be used as a companion to our [HSM Ingress ontroller](https://ingress.strid.tech). If you need TLS offload for your Azure Kubernetes cluster you can get it on [Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/stridtech.ingress-nginx-hsm) or [contact us](mailto:info@strid.tech).

### What does it do?

The HSM Ingress controller needs a custom `tls secret` which has a slightly different format since we don't have the actual key.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <name>
  namespace: <namespace>
type: "kubernetes.io/tls"
data:
  crt: base64(<PEM certificate>)
  # Normally the key is base64(<PEM key>)
  key: base64(engine:e_akv:hsm:<vault_name>:<key_name>)
```

If you don't want to handle the certificates outside of Azure KeyVault you can setup this controller to move the (public) certificiate into a secret together with the path for the HSM Ingress to find your key.

We have three "flavours", `HsmKey`, `AkvKey` and `CertKey`. Examples of how to use it in your cluster.

HsmKey:

```yaml
apiVersion: strid.tech/v1alpha
kind: HsmKey
metadata:
  name: example-hsm-key
  namespace: default
spec:
  hsm: <HSM name>
  akv: <AKV name>
  secret: <secret name stored in AKV>
  key: <key name stored in HSM>
  secret_name: <wanted cluster secret name>
```

AkvKey:

```yaml
apiVersion: strid.tech/v1alpha
kind: AkvKey
metadata:
  name: example-akv-key
  namespace: default
spec:
  akv: <AKV name>
  secret: <secret name stored in AKV>
  key: <key name stored in AKV>
  secret_name: <wanted cluster secret name>
```

CertKey:

```yaml
apiVersion: strid.tech/v1alpha
kind: CertKey
metadata:
  name: example-cert-key
  namespace: default
spec:
  akv: <AKV name>
  cert: <certificate name stored in AKV>
  secret_name: <wanted cluster secret name>
```

### Building

The repo is setup using Nix, we have a flake to build the container through [`nix2container`](https://github.com/nlewo/nix2container).

```sh
nix build .#container
```

### Contributing

The controller is written in OCaml and uses the [`dune`](https://github.com/ocaml/dune) build system.

If you want to work on the code we have a [`devenv`](https://devenv.sh) setup. You can either use `direnv` to get a automatic environment loaded or run the command `devenv shell` to get a shell with all needed dependencies.

When you have a shel you can just run `dune build` to build the project.

### Interested in using the HSM ingress?

You can get the HSM Ingress either through the Azure Marketplace or by contacting us at [info@strid.tech](mailto:info@strid.tech).

[<img width=270 height=90 src="./media/MS_Azure_Marketplace.png">](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/stridtech.ingress-nginx-hsm)
