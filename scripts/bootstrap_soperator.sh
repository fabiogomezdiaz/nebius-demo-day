#!/usr/bin/env bash
# Clone Soperator Terraform recipe at the pinned release tag and overlay our tfvars.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${SOPERATOR_TAG:-soperator-v4.1.8-1}"
INSTALL_NAME="${INSTALL_NAME:-demo-day}"
VENDOR="${ROOT}/vendor/nebius-solutions-library"
SRC_TFVARS="${ROOT}/terraform/installations/demo-day/terraform.tfvars"
DEST="${VENDOR}/soperator/installations/${INSTALL_NAME}"

if [[ ! -f "${SRC_TFVARS}" ]]; then
  echo "Missing overlay tfvars: ${SRC_TFVARS}" >&2
  exit 1
fi

mkdir -p "${ROOT}/vendor"

if [[ ! -d "${VENDOR}/.git" ]]; then
  echo "Cloning nebius-solutions-library @ ${TAG}"
  git clone --depth 1 --branch "${TAG}" \
    https://github.com/nebius/nebius-solutions-library.git \
    "${VENDOR}"
else
  echo "Updating existing clone to ${TAG}"
  git -C "${VENDOR}" fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}"
  git -C "${VENDOR}" checkout "${TAG}"
fi

echo "Creating installation ${DEST}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
# Copy example, including dotfiles (.envrc).
cp -a "${VENDOR}/soperator/installations/example/." "${DEST}/"
cp "${SRC_TFVARS}" "${DEST}/terraform.tfvars"

echo
echo "Pinned tag:        ${TAG}"
echo "Installation dir:  ${DEST}"
echo
echo "Next:"
echo "  1. Edit ${DEST}/.envrc  (NEBIUS_TENANT_ID, NEBIUS_PROJECT_ID, NEBIUS_REGION)"
echo "  2. Put your SSH public key in terraform.tfvars (this repo) and re-run this script,"
echo "     or edit ${DEST}/terraform.tfvars directly"
echo "  3. brew install yq   # required during terraform apply"
echo "  4. cd ${DEST} && source .envrc && terraform init && terraform apply"
echo
git -C "${VENDOR}" describe --tags --always
