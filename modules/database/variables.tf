###############################################
# Input Variables - Database Module
###############################################

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "component" {
  type    = string
  default = "database"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "ssm_db_password_param" {
  description = "SSM parameter name storing DB master password"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs for DB subnet group"
  type        = list(string)
}

variable "security_groups" {
  description = "Security group IDs for the DB cluster"
  type        = list(string)
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "instance_count" {
  type    = number
  default = 1
}
