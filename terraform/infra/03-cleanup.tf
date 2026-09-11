# 03-cleanup.tf — Project leftover cleanup.

module "cleanup" {
  source = "git::https://github.com/nebius/nebius-solutions-library.git//soperator/modules/cleanup?ref=soperator-v4.1.8-1"

  iam_project_id = var.iam_project_id
}
