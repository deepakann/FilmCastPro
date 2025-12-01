variable "aws_region" {
  default = "us-east-1"
}
variable "environment" {
  default = "dev"
}
variable "cluster_name" {
  default = "filmcastpro-eks-cluster"
}
variable "kubernetes_version" {
  default = "1.29"
}
variable "instance_type" {
  default = "t2.large"
}
variable "key_filename" {
  default = "CICDproject-kp"
}
variable "key_filepath" {
  default = "D:/MFH_Projects/CICDproject-kp.pem"
}

