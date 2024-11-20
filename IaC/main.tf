provider "aws" {
  region = var.region
}

# Create VPC
resource "aws_vpc" "topsurvey_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.topsurvey_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.topsurvey_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
}

# Create Private Subnets
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.topsurvey_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.topsurvey_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.region}b"
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.topsurvey_vpc.id
}

# Public Route Table and Route
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.topsurvey_vpc.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Create Key pair for ec2 Ec2 instance nodes
resource "tls_private_key" "eks_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "eks_key_pair" {
  key_name   = "eks-key-pair"
  public_key = tls_private_key.eks_key.public_key_openssh
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow RDS access"
  vpc_id      = aws_vpc.topsurvey_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Instance (PostgreSQL)
resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.3-R2"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.id
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}

# EKS Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.0.1"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = aws_vpc.topsurvey_vpc.id
  subnet_ids      = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]

  # Managed Node Group Configuration
  eks_managed_node_groups = {


    eks_nodes = {
      desired_capacity = var.desired_capacity
      max_capacity     = var.max_capacity
      min_capacity     = var.min_capacity
      instance_type    = var.node_instance_type
      key_name         = aws_key_pair.eks_key_pair.key_name
      metadata_options = {
        instance_metadata_tags = "disabled"
      }
    }

  }
}

# NLB for EKS
resource "aws_lb" "nlb" {
  name               = var.network_load_balancer_name
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

resource "aws_lb_target_group" "nlb_target_group" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.topsurvey_vpc.id
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group.arn
  }
}



# Print the private key to as a file
output "private_key_pem" {
  value     = tls_private_key.eks_key.private_key_pem
  sensitive = true
}