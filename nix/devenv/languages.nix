{ ocamlPackages }: # https://devenv.sh/languages/
{
  languages.nix.enable = true;
  languages.ocaml.enable = true;
  languages.ocaml.packages = ocamlPackages;
}
