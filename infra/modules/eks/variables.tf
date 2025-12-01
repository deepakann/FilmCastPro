variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for EKS"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for EKS"
}

variable "environment" {
  type        = string
  description = "Environment name"
}
