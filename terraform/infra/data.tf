data "nebius_iam_v1_project" "this" {
  id = var.iam_project_id
}

data "nebius_vpc_v1_subnet" "this" {
  id = var.vpc_subnet_id
}
