output "terraform_iam_role_arn" {
  value = aws_iam_role.terraform_role.arn
}

output "terraform_instance_profile_name" {
  value = aws_iam_instance_profile.terraform_profile.name
}

output "jenkins_iam_role_arn" {
  value = aws_iam_role.jenkins_role.arn
}

output "jenkins_instance_profile_name" {
  value = aws_iam_instance_profile.jenkins_ecr_profile.name
}