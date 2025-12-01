module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name                   = var.cluster_name
  cluster_version                = var.kubernetes_version
  subnet_ids                     = var.private_subnets
  vpc_id                         = var.vpc_id

  # Enable both endpoints, but route access properly
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false

  # Restrict public access to Jenkins/Terraform’s IP
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Enables IAM → Kubernetes auth through access entries & aws-auth
  authentication_mode = "API_AND_CONFIG_MAP"

  # Enable IRSA (for service accounts to assume roles)
  enable_irsa                    = true

  # Gives admin access to whoever created the cluster (e.g. Terraform root)
  enable_cluster_creator_admin_permissions = true

  # ---------------------------------------------------------------------------
  # Node Group Defaults — applies to all node groups
  # ---------------------------------------------------------------------------
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]
  
  # Add a clean tag for EC2 instances
    tags = {
      "Name"        = "${var.cluster_name}-${var.environment}-node"
      "Environment" = var.environment
    }
  }
  
  # ---------------------------------------------------------------------------
  #  Define a specific managed node group
  # ---------------------------------------------------------------------------

  eks_managed_node_groups = {
    cd-deploy-node-group = {
      min_size     = 2
      max_size     = 4
      desired_size = 2
    }
  }
  # ---------------------------------------------------------------------------
  # General cluster-level tags
  # ---------------------------------------------------------------------------

  tags = {
    Environment = var.environment
    Name        = "${var.cluster_name}-${var.environment}"
  }
}