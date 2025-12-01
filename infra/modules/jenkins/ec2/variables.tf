variable "instance_type" {}
variable "key_filename" {}
variable "key_filepath" {}
variable "aws_region" {}
variable "eks_cluster_name" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the Jenkins EC2 instance"
  type        = string
}