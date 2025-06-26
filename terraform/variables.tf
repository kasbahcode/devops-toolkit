# General Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devops-toolkit"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EKS Variables
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "Instance types for EKS managed node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "spot_instance_types" {
  description = "Instance types for spot node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 10
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 3
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = ""
}

# EKS Add-on Versions
variable "coredns_version" {
  description = "CoreDNS add-on version"
  type        = string
  default     = "v1.10.1-eksbuild.5"
}

variable "kube_proxy_version" {
  description = "Kube-proxy add-on version"
  type        = string
  default     = "v1.28.2-eksbuild.2"
}

variable "vpc_cni_version" {
  description = "VPC CNI add-on version"
  type        = string
  default     = "v1.15.1-eksbuild.1"
}

variable "ebs_csi_version" {
  description = "EBS CSI driver add-on version"
  type        = string
  default     = "v1.24.0-eksbuild.1"
}

# AWS Auth Users
variable "aws_auth_users" {
  description = "List of AWS users to add to aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# Database Variables
variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "devops_toolkit"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "changeme123!"
}

# Redis Variables
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes in the Redis cluster"
  type        = number
  default     = 1
}

variable "redis_auth_token" {
  description = "Redis auth token"
  type        = string
  sensitive   = true
  default     = "changeme123!"
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
} 