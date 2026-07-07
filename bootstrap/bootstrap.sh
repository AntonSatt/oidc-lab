#!/usr/bin/env bash
# Hönan-och-ägget: state-backendens egen infrastruktur kan inte bo i
# state:en den ska lagra. Körs EN gång, för hand, som du själv (samma
# roll som pop-infras bootstrap/-katalog).
#
# Användning: ./bootstrap.sh <storage-kontonamn>
#   Namnet måste vara globalt unikt, 3-24 tecken, bara a-z0-9.
#   Exempel: ./bootstrap.sh stoidclabanton001
set -euo pipefail

STORAGE_ACCOUNT="${1:?Ange storage-kontonamn, t.ex. stoidclabanton001}"
LOCATION="polandcentral"
RESOURCE_GROUP="rg-oidclab-mgmt-${LOCATION}-001"
CONTAINER="tfstate"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# --auth-mode login: gå via Entra, inte kontonycklar. Kräver att du har
# Blob Data-rätt - därav rolltilldelningen nedan; kör om containersteget
# om replikeringen inte hunnit ikapp första gången.
SELF_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
ACCOUNT_ID="$(az storage account show --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" --query id -o tsv)"

# Du själv som operatör: läsa/skriva state lokalt (identities-stacken
# kör med lokal state, men du behöver rollen för infra/-stacken).
az role assignment create \
  --assignee "$SELF_OBJECT_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$ACCOUNT_ID"

az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login

echo ""
echo "Klart. Anteckna till identities/terraform.tfvars och infra/backend.tf:"
echo "  storage_account_name = \"$STORAGE_ACCOUNT\""
