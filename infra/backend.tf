terraform {
  backend "s3" {
    bucket = "filmcastpro-tf-bucket"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}