provider "aws" {
  region = "us-east-1"  # Change if you prefer another region
}

# --- VPC & Networking (Free Tier Friendly) ---
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "devops-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# --- Security Groups ---
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For production, restrict this to your own IP!
  }

  # HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins Port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Kubernetes API (6443) & NodePorts (30000-32767)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 30000
    to_port     = 32767
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

# --- Key Pair ---
resource "aws_key_pair" "deployer" {
  key_name   = "devops-project-key"
  public_key = file("my-key.pub")
}

# --- EC2 Instance 1: Jenkins Server ---
resource "aws_instance" "jenkins" {
  ami           = "ami-04b4f1a9cf54c11d0" # Ubuntu 24.04 LTS (us-east-1)
  instance_type = "t2.micro"             # Needed for Jenkins+Java. t2.micro WILL crash.
                                          # WARNING: t2.medium is NOT free tier.
                                          # IF YOU MUST USE FREE TIER: Change to "t2.micro" 
                                          # but expect slowness and potential crashes.
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  tags = { Name = "Jenkins-Server" }

  # Script to install Jenkins & Docker on boot
  user_data = <<-EOF
              #!/bin/bash
              # Add swap space to prevent crashing on small instances
              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab
              
              # Install Java & Jenkins
              wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
              echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
              apt-get update
              apt-get install -y fontconfig openjdk-17-jre jenkins docker.io
              
              # Permissions
              usermod -aG docker ubuntu
              usermod -aG docker jenkins
              systemctl enable jenkins
              systemctl start jenkins
              EOF
}

# --- EC2 Instance 2: Kubernetes (K3s) Cluster ---
resource "aws_instance" "k8s" {
  ami           = "ami-04b4f1a9cf54c11d0" 
  instance_type = "t2.micro"             # Free tier eligible
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  tags = { Name = "K8s-Cluster" }

  # Script to install K3s (Lightweight Kubernetes)
  user_data = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | sh -
              # Allow 'ubuntu' user to use kubectl
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown ubuntu:ubuntu /home/ubuntu/.kube/config
              chmod 600 /home/ubuntu/.kube/config
              EOF
}

# --- Outputs ---
output "jenkins_ip" {
  value = aws_instance.jenkins.public_ip
}

output "k8s_ip" {
  value = aws_instance.k8s.public_ip
}
