#############################################
# Terraform Deploy Role (for infrastructure)
#############################################
resource "aws_iam_role" "terraform_role" {
  name = "terraform-cddeploy-eksrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# Full access for Terraform to create & manage all resources
resource "aws_iam_role_policy_attachment" "terraform_role_attach" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "terraform_profile" {
  name = "cdterraforminstanceprofile"
  role = aws_iam_role.terraform_role.name
}

#############################################
# Jenkins IAM Role (for EC2 instance & EKS access)
#############################################

resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-cddeploy-eksrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach needed permissions (can start limited and expand as needed)
resource "aws_iam_role_policy_attachment" "jenkins_ecr_access" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#############################################
# Instance Profile for Jenkins EC2
#############################################
resource "aws_iam_instance_profile" "jenkins_ecr_profile" {
  name = "cdjenkinsinstanceprofile"
  role = aws_iam_role.jenkins_role.name
}