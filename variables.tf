variable "project" { default = "km" }
variable "environment" { default = "dev" }
variable "region" { default = "us-east-1" }

# VPC
variable "vpc_cidr" { default = "10.10.0.0/16" }
variable "az_count" { default = 2 }
variable "public_subnet_cidrs" { default = ["10.10.1.0/24","10.10.2.0/24"] }
variable "private_subnet_cidrs" { default = ["10.10.101.0/24","10.10.102.0/24"] }
variable "enable_nat_per_az" { default = false }
variable "access_cidr" { default = "34.229.141.205/32" }

# EKS
variable "eks_cluster_version" { default = "1.29" }
variable "node_group_desired_size" { default = 2 }
variable "node_group_min_size" { default = 1 }
variable "node_group_max_size" { default = 5 }
variable "node_instance_type" { default = "t3.medium" }

# Aurora
variable "aurora_engine_version" { default = "8.0.mysql_aurora.3.08.2" }
variable "aurora_serverless_v2_scaling_min" { default = 0.5 }
variable "aurora_serverless_v2_scaling_max" { default = 4 }
variable "aurora_backup_retention_days" { default = 7 }
variable "aurora_master_username" { default = "admin" }
# We will create password via random_password & SSM in root below
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {
    Project     = "km"
    Owner       = "Supuni"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
