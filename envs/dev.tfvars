project     = "km"
environment = "dev"
region      = "us-east-1"

# VPC
vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24","10.10.2.0/24"]
private_subnet_cidrs = ["10.10.101.0/24","10.10.102.0/24"]
az_count             = 2
enable_nat_per_az    = false
access_cidr          = "34.229.141.205/32"

# EKS sizing
eks_cluster_version     = "1.29"
node_group_desired_size = 2
node_group_min_size     = 1
node_group_max_size     = 5
node_instance_type      = "t3.medium"

# Aurora
aurora_engine_version = "8.0.mysql_aurora.3.08.2"
aurora_serverless_v2_scaling_min = 0.5
aurora_serverless_v2_scaling_max = 4
aurora_backup_retention_days = 7
db_instance_class = "db.t3.medium"


tags = {
  Project     = "km"
  Owner       = "kmprojectteam"
  ManagedBy   = "Terraform"
  Environment = "dev"
}
