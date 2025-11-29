locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  project                = var.project
  component              = "vpc"
  environment            = var.environment
  region                 = var.region
  vpc_cidr               = var.vpc_cidr
  az_count               = var.az_count
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  enable_nat_per_az      = var.enable_nat_per_az
  access_cidr            = var.access_cidr
  tags                   = var.tags
}

# Create DB password and store in SSM (recommended)
resource "random_password" "aurora_master_password" {
  length  = 32
  special = true
}

resource "aws_ssm_parameter" "aurora_password" {
  name  = "/${var.project}/${var.environment}/db/master_password"
  type  = "SecureString"
  value = random_password.aurora_master_password.result
  tags = {
    Name = "${local.name_prefix}-aurora-password"
  }
  overwrite   = true       # ADD THIS LINE
}

# Aurora module reads password from SSM (we pass the key)
module "database" {
  source = "./modules/database"

  project       = var.project
  environment   = var.environment
  component     = "database"
  tags          = var.tags

  db_name       = "kubeplatform"
  db_username   = var.aurora_master_username

  private_subnets = module.network.private_subnet_ids
  security_groups = [module.network.security_group_ids["db"]]

  ssm_db_password_param = "/km/dev/db/master_password"

  instance_count   = 1
  db_instance_class = "db.serverless"
}


# EKS module
module "eks" {
  source = "./modules/eks"

  project                 = var.project
  environment             = var.environment
  component               = "eks"
  region                  = var.region
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  node_security_group_ids = [module.network.security_group_ids["eks_nodes"]]
  eks_cluster_version     = var.eks_cluster_version
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_instance_type      = var.node_instance_type
  tags                    = var.tags
}

# SSM params for downstream apps / devs (expose endpoint & username)
resource "aws_ssm_parameter" "aurora_endpoint" {
  name  = "/${var.project}/${var.environment}/db/endpoint"
  type  = "String"
  value = module.database.cluster_endpoint
  tags = {
    Name = "${local.name_prefix}-aurora-endpoint"
  }
}

resource "aws_ssm_parameter" "aurora_username" {
  name  = "/${var.project}/${var.environment}/db/username"
  type  = "String"
  value = var.aurora_master_username
  tags = {
    Name = "${local.name_prefix}-aurora-username"
  }
}
