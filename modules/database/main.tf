########################################################
# Data
########################################################
data "aws_region" "current" {}

data "aws_ssm_parameter" "db_pw" {
  name            = var.ssm_db_password_param
  with_decryption = true
}

########################################################
# Locals
########################################################
locals {
  region_nodash = replace(data.aws_region.current.id, "-", "")
  name_prefix   = "${var.project}-${var.environment}-${var.component}-${local.region_nodash}"

  base_tags = merge(var.tags, {
    Name        = local.name_prefix
    Project     = var.project
    Environment = var.environment
    Component   = var.component
    ManagedBy   = "terraform"
  })

  master_password = data.aws_ssm_parameter.db_pw.value
}

########################################################
# DB Subnet Group
########################################################
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-subnet-group"
  })
}

########################################################
# RDS Aurora Cluster
########################################################
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${local.name_prefix}-cluster"
  engine             = "aurora-mysql"
  engine_version     = "8.0.mysql_aurora.3.04.0"

  database_name      = var.db_name
  master_username    = var.db_username
  master_password    = local.master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_groups

  storage_encrypted = true
  backup_retention_period = 1

  tags = local.base_tags
}

########################################################
# RDS Reader Instance
########################################################
resource "aws_rds_cluster_instance" "aurora_instances" {
  count                = var.instance_count
  identifier           = "${local.name_prefix}-instance-${count.index}"
  cluster_identifier   = aws_rds_cluster.aurora.id
  instance_class       = var.db_instance_class
  engine               = aws_rds_cluster.aurora.engine
  engine_version       = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.main.name

  tags = local.base_tags
}

########################################################
# Outputs
########################################################
output "aurora_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  value = aws_rds_cluster.aurora.reader_endpoint
}
