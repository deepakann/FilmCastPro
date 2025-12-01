output "eks_cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "jenkins_instance_public_ip" {
  value = module.jenkins.public_ip
}
output "vpc_id" {
  value = module.vpc.vpc_id
}