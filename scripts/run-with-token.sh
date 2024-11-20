#!/usr/bin/env bash

set -e

AKV_ACCESS_TOKEN=$(az account get-access-token --resource https://vault.azure.net --query accessToken --output tsv)
AKV=stab-dev-akv-01
CERTIFICATE=stab-dev-akvc-01

export AKV_ACCESS_TOKEN

dune exec src/bin/akv_cert_secret.exe -- --akv "$AKV" --name "$CERTIFICATE"
