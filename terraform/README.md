# Terraform overlay

This directory is **not** a standalone root module. The Soperator recipe (`main.tf`, modules, `.envrc`) lives in the tagged Nebius solutions library.

## Apply flow

```bash
# from repo root
./scripts/bootstrap_soperator.sh

cd vendor/nebius-solutions-library/soperator/installations/demo-day
# set NEBIUS_TENANT_ID and NEBIUS_PROJECT_ID in .envrc
# paste SSH public key into terraform.tfvars if you have not already
source .envrc
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Install `yq` on the machine that runs Terraform **before** apply.

## What we overlay

Only `terraform.tfvars`. See [docs/terraform-infiniband-changes.md](../docs/terraform-infiniband-changes.md) for the InfiniBand / nodeset diffs versus `installations/example`.

## After apply

```bash
./login.sh -k ~/.ssh/<private-key>
```

Leave the cluster running for the demo interview. Destroy only after they say to decommission.
