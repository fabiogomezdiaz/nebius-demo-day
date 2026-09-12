#----------------------------------------------------------------------------------------------------------------------#
# Demo Day overlay for Soperator Terraform recipe soperator-v4.1.8-1
#
# Apply from this directory. terraform init fetches Soperator modules from
# github.com/nebius/nebius-solutions-library @ soperator-v4.1.8-1.
# Node groups, filestore sizes, and Slurm flags are hardcoded in .tf.
#
# ./scripts/01-seed_tfvars.sh writes region, tenant, project, and subnet here.
#----------------------------------------------------------------------------------------------------------------------#

company_name   = "fabio-demo"
iam_project_id = "project-e00dqh87pr00x1qed0hwcy"
iam_tenant_id  = "tenant-e00vj0jkxzwvp8q5xe"
region         = "eu-north1"
vpc_subnet_id  = "vpcsubnet-e00rnj9nfp6qysd3pr"
