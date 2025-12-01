#############################################
#  Get Ubuntu AMI
#############################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#############################################
#  Security Group for Jenkins
#############################################

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow Jenkins and SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#############################################
#  Jenkins EC2 Instance
#############################################

resource "aws_instance" "jenkins_ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_filename
  subnet_id                   = var.subnet_id
  associate_public_ip_address  = true
  vpc_security_group_ids       = [aws_security_group.jenkins_sg.id]
  iam_instance_profile          = var.iam_instance_profile 

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.key_filepath)
    host        = self.public_ip
    timeout     = "5m"
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  #############################################
  # 🔸 Wait for EKS cluster to become active
  #############################################
   provisioner "remote-exec" {
    inline = [
      "echo '🔹 Installing prerequisites (curl & unzip) if missing...'",
      "sudo apt-get update -y",
      "sudo apt-get install -y gnupg software-properties-common unzip curl",

      "echo '🔹 Installing AWS CLI v2 (if missing)...'",
      # Install AWS CLI v2 idempotently
      "if ! command -v aws &> /dev/null; then curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip -o awscliv2.zip && sudo ./aws/install --update; fi",
      "echo 'aws version:' && if command -v aws &> /dev/null; then aws --version; else echo 'aws CLI not installed'; fi",

      # Wait for EKS cluster to be fully active
      "echo '🔹 Waiting for EKS cluster ${var.eks_cluster_name} to become ACTIVE...'",
      "for i in {1..25}; do STATUS=$(aws eks describe-cluster --region ${var.aws_region} --name ${var.eks_cluster_name} --query 'cluster.status' --output text 2>/dev/null || echo NOTFOUND); if [ \"$STATUS\" = \"ACTIVE\" ]; then echo '✅ EKS is ACTIVE!'; break; fi; echo \"⏳ EKS status: $STATUS - sleeping 30s\"; sleep 30; done",

      # ✅ Wait for Jenkins IAM access entry to propagate into EKS
      "echo '🔹 Waiting for Jenkins EKS access entry to propagate...'",
      "for i in {1..20}; do",
      "  if aws eks list-access-entries --region ${var.aws_region} --cluster-name ${var.eks_cluster_name} | grep -q 'jenkins'; then",
      "    echo 'Jenkins access entry found in EKS!';",
      "    break;",
      "  fi",
      "  echo '⏳ Waiting for access entry to appear (retry' $i ')...';",
      "  sleep 15;",
      "done"
    ]
  }

  #############################################
  # Jenkins + Docker + AWS CLI + kubectl setup
  #############################################

  provisioner "remote-exec" {
    inline = [
      "echo '🔹 Installing Jenkins, Docker, kubectl, Helm, ArgoCD...'",
      "sudo apt update -y",
      "sudo apt install -y gnupg curl openjdk-17-jdk apt-transport-https ca-certificates lsb-release unzip",
      "java -version",

      # Jenkins setup
      "curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null",
      "echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
      "sudo apt update -y",
      "sudo apt install -y jenkins",
      "sudo systemctl enable jenkins",
      "sudo systemctl start jenkins",

      # Docker setup
      "sudo apt-get install -y apt-transport-https ca-certificates gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io",
      "sudo usermod -aG docker ubuntu",
      "sudo usermod -aG docker jenkins",
      "sudo systemctl restart jenkins || true",

      # kubectl
      "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl",
      "chmod +x kubectl && sudo mv kubectl /usr/local/bin/",
      "kubectl version --client",

      # Configure Kubeconfig for Jenkins
      "sudo mkdir -p /var/lib/jenkins/.kube",
      "sudo chown jenkins:jenkins /var/lib/jenkins/.kube",
      "sudo -u jenkins aws eks update-kubeconfig --region ${var.aws_region} --name ${var.eks_cluster_name} --kubeconfig /var/lib/jenkins/.kube/config || true",
      "sudo chmod 600 /var/lib/jenkins/.kube/config || true",

      # Helm
      "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",
      "helm version --client",

      # ArgoCD CLI
      "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64",
      "chmod +x argocd-linux-amd64 && sudo mv argocd-linux-amd64 /usr/local/bin/argocd",
      "argocd version --client",

      # Final verification - ensure Jenkins can connect and has rights
      "echo '🔹 Validating Jenkins → EKS access...'",
      "if sudo -u jenkins kubectl get nodes >/dev/null 2>&1; then echo '✅ kubectl get nodes: OK'; else echo '❌ kubectl get nodes: FAILED'; fi",
      "if sudo -u jenkins kubectl auth can-i create pods --all-namespaces >/dev/null 2>&1; then echo '✅ Jenkins has cluster-admin privileges'; else echo '❌ Jenkins does NOT have cluster-admin privileges — check IAM/AccessEntry mapping'; fi"
    ]
}

  tags = {
    Name = "FCP-Jenkins-Infra"
    Environment = "dev"
  }
}

     