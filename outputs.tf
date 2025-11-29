output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_ca" {
  value     = module.eks.cluster_ca_certificate
  sensitive = true
}

output "aurora_cluster_endpoint" {
  value = module.database.cluster_endpoint
}

output "ssm_db_password_param" {
  value = aws_ssm_parameter.aurora_password.name
}
