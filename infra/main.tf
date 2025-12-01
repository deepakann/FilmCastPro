terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# ────────────────────────────────
# VPC Creation
# ────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = "${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    Environment = var.environment
  }
}

# ────────────────────────────────
# EKS Cluster (includes Jenkins access)
# ────────────────────────────────
module "eks_cluster" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnets    = module.vpc.private_subnets
  environment        = var.environment
}

# ────────────────────────────────
# Jenkins IAM Role (separate)
# ────────────────────────────────
module "jenkins_iam" {
  source = "./modules/jenkins/iam"
}

# ────────────────────────────────
# Terraform Deploy Role Access Entry 
# ────────────────────────────────
resource "aws_eks_access_entry" "terraform_access" {
  depends_on = [module.eks_cluster]

  cluster_name      = module.eks_cluster.cluster_name
  principal_arn     = module.jenkins_iam.terraform_iam_role_arn
  type              = "STANDARD"
  user_name         = "terraformadmin"

  # reduce recreate conflicts on small changes
  lifecycle {
    ignore_changes = [principal_arn, kubernetes_groups]
    prevent_destroy = false
  }
}

# ------------------------------------------------------------------
# Add Terraform IAM role into EKS's access entries so the role can authenticate
# ------------------------------------------------------------------
resource "aws_eks_access_policy_association" "terraform_cluster_admin" {
  depends_on = [aws_eks_access_entry.terraform_access]

  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = module.jenkins_iam.terraform_iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ------------------------------------------------------------------
# Add Jenkins IAM role into EKS's access entries so the role can authenticate
# ------------------------------------------------------------------
resource "aws_eks_access_entry" "jenkins_access" {
  depends_on = [module.eks_cluster, module.jenkins_iam, aws_eks_access_policy_association.terraform_cluster_admin]

  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = module.jenkins_iam.jenkins_iam_role_arn
  type          = "STANDARD"
  user_name     = "jenkins"
  kubernetes_groups = ["cluster-admins"]

  # reduce recreate conflicts on small changes
  lifecycle {
    ignore_changes = [principal_arn, kubernetes_groups]
    prevent_destroy = false
  }
}

# ------------------------------------------------------------------
# Grant Jenkins IAM role cluster-admin permissions in EKS
# ------------------------------------------------------------------
resource "aws_eks_access_policy_association" "jenkins_cluster_admin" {
  depends_on = [aws_eks_access_entry.jenkins_access]

  cluster_name  = module.eks_cluster.cluster_name
  principal_arn = module.jenkins_iam.jenkins_iam_role_arn

  # EKS managed access policy for cluster-admin
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# ------------------------------------------------------------------
# Wait for IAM Propagation Delay (EKS Access)
# ------------------------------------------------------------------
resource "time_sleep" "wait_for_eks_access_propagation" {
  depends_on = [
    aws_eks_access_policy_association.jenkins_cluster_admin,
    aws_eks_access_policy_association.terraform_cluster_admin
  ]

  create_duration = "120s" # wait 2 minutes for IAM/EKS access propagation
}

# ────────────────────────────────
# Jenkins EC2 (creates IAM role & EC2)
# ────────────────────────────────
module "jenkins" {
  source           = "./modules/jenkins/ec2"
  instance_type    = var.instance_type
  key_filename     = var.key_filename
  key_filepath     = var.key_filepath
  aws_region       = var.aws_region
  eks_cluster_name = var.cluster_name
  vpc_id           = module.vpc.vpc_id
  subnet_id        = element(module.vpc.public_subnets, 0)
  iam_instance_profile = module.jenkins_iam.jenkins_instance_profile_name

  depends_on = [time_sleep.wait_for_eks_access_propagation]
}

# Kubernetes provider (use the EKS outputs)
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
  depends_on = [time_sleep.wait_for_eks_access_propagation] 
}

# Create ClusterRoleBinding mapping our 'cluster-admins' group to cluster-admin role.
# Wait until access_entry has been created & waited on.
resource "kubernetes_cluster_role_binding" "jenkins_admin_binding" {
  metadata {
    name = "jenkins-cluster-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "Group"
    name      = "cluster-admins" # this group will be associated with the Jenkins IAM principal via access entry
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [time_sleep.wait_for_eks_access_propagation]
}