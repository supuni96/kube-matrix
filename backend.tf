terraform {
  backend "s3" {
    bucket = "km-tfstate-bucket"
    key    = "envs/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
