variable "project" {
  type        = string
  description = "Project name (e.g., km)"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, stage, prod)"
}

variable "component" {
  type        = string
  default     = "eks"
  description = "Component name"
}

variable "region" {
  type        = string
  description = "AWS region (e.g., us-east-1)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "node_security_group_ids" {
  type        = list(string)
  description = "Security groups for EKS worker nodes"
}

variable "eks_cluster_version" {
  type        = string
  default     = "1.29"
  description = "EKS Kubernetes version"
}

variable "node_group_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of worker nodes"
}

variable "node_group_min_size" {
  type        = number
  default     = 2
  description = "Minimum number of worker nodes"
}

variable "node_group_max_size" {
  type        = number
  default     = 4
  description = "Maximum number of worker nodes (kept 1 for free-tier)"
}

variable "node_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type for EKS worker nodes"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all EKS resources"
}
