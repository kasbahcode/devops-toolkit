terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "devops-toolkit-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "DevOps Toolkit"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "DevOps Team"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "development"
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Enable flow logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = local.common_tags
}

# Security Groups
resource "aws_security_group" "additional" {
  name_prefix = "${local.cluster_name}-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Encryption key
  create_kms_key = true
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = module.eks.kms_key_arn
  }

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # IRSA
  enable_irsa = true

  # Managed node groups
  eks_managed_node_groups = {
    main = {
      name = "main"

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Launch template configuration
      create_launch_template = false
      launch_template_name   = ""

      disk_size = 50
      disk_type = "gp3"

      # Remote access
      remote_access = {
        ec2_ssh_key               = var.key_pair_name
        source_security_group_ids = [aws_security_group.additional.id]
      }

      # Kubernetes labels
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # Kubernetes taints
      taints = {}

      tags = local.common_tags
    }

    spot = {
      name = "spot"

      instance_types = var.spot_instance_types
      capacity_type  = "SPOT"

      min_size     = 0
      max_size     = 10
      desired_size = var.environment == "production" ? 2 : 0

      disk_size = 50
      disk_type = "gp3"

      labels = {
        Environment = var.environment
        NodeGroup   = "spot"
        "node.kubernetes.io/lifecycle" = "spot"
      }

      taints = {
        spot = {
          key    = "node.kubernetes.io/lifecycle"
          value  = "spot"
          effect = "NO_SCHEDULE"
        }
      }

      tags = merge(local.common_tags, {
        "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle" = "spot"
        "k8s.io/cluster-autoscaler/node-template/taint/node.kubernetes.io/lifecycle" = "spot:NoSchedule"
      })
    }
  }

  # Fargate profiles
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        },
        {
          namespace = "default"
        }
      ]

      tags = local.common_tags
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/DevOpsRole"
      username = "devops"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = var.aws_auth_users

  tags = local.common_tags
}

# Add-ons
resource "aws_eks_addon" "addons" {
  for_each = {
    coredns = {
      version = var.coredns_version
    }
    kube-proxy = {
      version = var.kube_proxy_version
    }
    vpc-cni = {
      version = var.vpc_cni_version
    }
    aws-ebs-csi-driver = {
      version = var.ebs_csi_version
    }
  }

  cluster_name             = module.eks.cluster_name
  addon_name               = each.key
  addon_version            = each.value.version
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  tags = local.common_tags
}

# RDS Instance
resource "aws_db_subnet_group" "default" {
  name       = "${local.cluster_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${local.cluster_name}-rds"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.cluster_name}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name

  backup_retention_period = var.environment == "production" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment != "production"
  deletion_protection = var.environment == "production"

  performance_insights_enabled = var.environment == "production"
  monitoring_interval         = var.environment == "production" ? 60 : 0

  tags = local.common_tags
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "default" {
  name       = "${local.cluster_name}-cache-subnet"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "redis" {
  name_prefix = "${local.cluster_name}-redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${local.cluster_name}-redis"
  description                = "Redis cluster for ${local.cluster_name}"

  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = "default.redis7"

  num_cache_clusters = var.redis_num_cache_nodes
  
  subnet_group_name  = aws_elasticache_subnet_group.default.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  automatic_failover_enabled = var.redis_num_cache_nodes > 1

  tags = local.common_tags
}

# S3 Buckets
resource "aws_s3_bucket" "app_storage" {
  bucket = "${local.cluster_name}-app-storage"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${local.cluster_name}/application"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = local.common_tags
}

# IAM Roles for Service Accounts
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${local.cluster_name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.cluster_autoscaler.name
}

# Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  sensitive   = true
} 